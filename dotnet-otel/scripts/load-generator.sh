#!/bin/sh
set -eu

APP_URL="${APP_URL:-http://app:8050}"
REQUESTS_PER_API="${REQUESTS_PER_API:-50}"
FAILED_REQUESTS_PER_API="${FAILED_REQUESTS_PER_API:-10}"
CYCLE_SECONDS="${CYCLE_SECONDS:-300}"
SLOW_REQUESTS_PER_CYCLE="${SLOW_REQUESTS_PER_CYCLE:-5}"
SLOW_REQUEST_DELAY_MS="${SLOW_REQUEST_DELAY_MS:-1200}"
SLOW_DB_DELAY_MS="${SLOW_DB_DELAY_MS:-600}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-15}"
SUCCESS_REQUESTS=$((REQUESTS_PER_API - FAILED_REQUESTS_PER_API))

if [ "$SUCCESS_REQUESTS" -lt 0 ]; then
  echo "FAILED_REQUESTS_PER_API cannot exceed REQUESTS_PER_API" >&2
  exit 1
fi

body_file="$(mktemp)"
ids_file="$(mktemp)"
trap 'rm -f "$body_file" "$ids_file"' EXIT

request() {
  method="$1" path="$2" payload="${3-}"
  if [ -n "$payload" ]; then
    curl -sS -o "$body_file" -w '%{http_code}' --max-time "$REQUEST_TIMEOUT" \
      -X "$method" -H 'Content-Type: application/json' -d "$payload" "$APP_URL$path" 2>/dev/null || printf '000'
  else
    curl -sS -o "$body_file" -w '%{http_code}' --max-time "$REQUEST_TIMEOUT" \
      -X "$method" "$APP_URL$path" 2>/dev/null || printf '000'
  fi
}

check() {
  expected="$1" status="$2" label="$3"
  case "$expected:$status" in
    success:2*|failure:4*|failure:5*) return ;;
    *) echo "Unexpected response for $label ($expected): HTTP $status" ;;
  esac
}

echo "Waiting for $APP_URL/health"
until curl -fsS --max-time "$REQUEST_TIMEOUT" "$APP_URL/health" >/dev/null 2>&1; do sleep 2; done

cycle=0
while true; do
  cycle=$((cycle + 1))
  started="$(date +%s)"
  : > "$ids_file"
  echo "Starting load cycle $cycle"

  i=1
  while [ "$i" -le "$SUCCESS_REQUESTS" ]; do
    payload="{\"title\":\"load-$cycle-$i\",\"description\":\"generated load\",\"completed\":false}"
    status="$(request POST /tasks/api/ "$payload")"
    check success "$status" 'POST /tasks/api'
    sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p' "$body_file" >> "$ids_file"
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le "$FAILED_REQUESTS_PER_API" ]; do
    status="$(request POST /tasks/api/ '{"title":')"
    check failure "$status" 'POST /tasks/api'
    i=$((i + 1))
  done

  i=1
  while [ "$i" -le "$REQUESTS_PER_API" ]; do
    if [ "$i" -le "$FAILED_REQUESTS_PER_API" ]; then
      status="$(request GET '/tasks/api/?fail=true')"; check failure "$status" 'GET /tasks/api'
    else
      status="$(request GET '/tasks/api/?fail=false')"; check success "$status" 'GET /tasks/api'
    fi
    i=$((i + 1))
  done

  i=1
  while [ "$i" -le "$SUCCESS_REQUESTS" ]; do
    id="$(sed -n "${i}p" "$ids_file")"
    status="$(request GET "/tasks/api/$id")"; check success "$status" 'GET task'
    payload="{\"title\":\"updated-$cycle-$i\",\"completed\":true}"
    status="$(request PUT "/tasks/api/$id" "$payload")"; check success "$status" 'PUT task'
    status="$(request DELETE "/tasks/api/$id")"; check success "$status" 'DELETE task'
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le "$FAILED_REQUESTS_PER_API" ]; do
    status="$(request GET /tasks/api/999999999)"; check failure "$status" 'GET missing task'
    status="$(request PUT /tasks/api/999999999 '{"title":"missing"}')"; check failure "$status" 'PUT missing task'
    status="$(request DELETE /tasks/api/999999999)"; check failure "$status" 'DELETE missing task'
    status="$(request GET '/tasks/api/test/bad-query?fail=true')"; check failure "$status" 'bad query'
    i=$((i + 1))
  done

  i=1
  while [ "$i" -le "$SLOW_REQUESTS_PER_CYCLE" ]; do
    kind=slow-db-read; [ $((i % 2)) -eq 0 ] && kind=slow-db-write
    status="$(request GET "/tasks/api/test/$kind?delayMs=$SLOW_REQUEST_DELAY_MS&dbDelayMs=$SLOW_DB_DELAY_MS")"
    check success "$status" "$kind"
    i=$((i + 1))
  done

  elapsed=$(( $(date +%s) - started ))
  remaining=$((CYCLE_SECONDS - elapsed))
  echo "Completed load cycle $cycle in ${elapsed}s"
  [ "$remaining" -le 0 ] || sleep "$remaining"
done
