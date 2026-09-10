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

SUCCESS_REQUESTS_PER_API=$((REQUESTS_PER_API - FAILED_REQUESTS_PER_API))

if [ "${SUCCESS_REQUESTS_PER_API}" -lt 0 ]; then
  echo "FAILED_REQUESTS_PER_API must be less than or equal to REQUESTS_PER_API" >&2
  exit 1
fi

BODY_FILE="$(mktemp)"
TASK_IDS_FILE="$(mktemp)"
trap 'rm -f "${BODY_FILE}" "${TASK_IDS_FILE}"' EXIT

echo "Waiting for ${APP_URL}/tasks/api"
until curl -fsS --max-time "${REQUEST_TIMEOUT}" "${APP_URL}/tasks/api" >/dev/null 2>&1; do
  sleep 2
done

echo "Starting load generation: ${REQUESTS_PER_API} requests per API every ${CYCLE_SECONDS}s (${FAILED_REQUESTS_PER_API} failures per API, ${SLOW_REQUESTS_PER_CYCLE} slow DB requests with ${SLOW_DB_DELAY_MS}ms DB delay)"
cycle=0

curl_request() {
  method="$1"
  url="$2"
  payload="${3-}"

  if [ -n "${payload}" ]; then
    status="$(curl -sS -o "${BODY_FILE}" -w "%{http_code}" --max-time "${REQUEST_TIMEOUT}" \
      -X "${method}" \
      -H "Content-Type: application/json" \
      -d "${payload}" \
      "${url}" 2>/dev/null || true)"
  else
    status="$(curl -sS -o "${BODY_FILE}" -w "%{http_code}" --max-time "${REQUEST_TIMEOUT}" \
      -X "${method}" \
      "${url}" 2>/dev/null || true)"
  fi

  if [ -n "${status}" ]; then
    printf "%s" "${status}"
  else
    printf "000"
  fi
}

record_result() {
  api_name="$1"
  expected="$2"
  status="$3"

  if [ "${expected}" = "success" ]; then
    case "${status}" in
      2*) return 0 ;;
    esac
  else
    case "${status}" in
      4*|5*) return 0 ;;
    esac
  fi

  unexpected_results=$((unexpected_results + 1))
  echo "Unexpected ${api_name} ${expected} response: HTTP ${status}"
}

send_request() {
  api_name="$1"
  expected="$2"
  method="$3"
  path="$4"
  payload="${5-}"

  status="$(curl_request "${method}" "${APP_URL}${path}" "${payload}")"
  record_result "${api_name}" "${expected}" "${status}"
}

send_slow_request() {
  index="$1"

  if [ $((index % 2)) -eq 0 ]; then
    send_request "GET /tasks/api/test/slow-db-write" "success" "GET" "/tasks/api/test/slow-db-write?delayMs=${SLOW_REQUEST_DELAY_MS}&dbDelayMs=${SLOW_DB_DELAY_MS}"
  else
    send_request "GET /tasks/api/test/slow-db-read" "success" "GET" "/tasks/api/test/slow-db-read?delayMs=${SLOW_REQUEST_DELAY_MS}&dbDelayMs=${SLOW_DB_DELAY_MS}"
  fi
}

create_task() {
  index="$1"
  expected="$2"

  if [ "${expected}" = "success" ]; then
    title="load-cycle-${cycle}-task-${index}"
    payload=$(printf '{"title":"%s","description":"Generated load cycle %s request %s","completed":false}' "${title}" "${cycle}" "${index}")
  else
    payload='{"title":'
  fi

  status="$(curl_request "POST" "${APP_URL}/tasks/api" "${payload}")"
  record_result "POST /tasks/api" "${expected}" "${status}"

  if [ "${expected}" = "success" ]; then
    task_id="$(sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p' "${BODY_FILE}")"
    if [ -n "${task_id}" ]; then
      printf "%s\n" "${task_id}" >> "${TASK_IDS_FILE}"
    fi
  fi
}

task_id_for_index() {
  index="$1"
  task_id="$(sed -n "${index}p" "${TASK_IDS_FILE}")"
  if [ -n "${task_id}" ]; then
    printf "%s" "${task_id}"
  else
    printf "0"
  fi
}

while true; do
  cycle=$((cycle + 1))
  unexpected_results=0
  cycle_start="$(date +%s)"
  : > "${TASK_IDS_FILE}"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    create_task "${i}" "success"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    create_task "${i}" "failure"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed POST /tasks/api"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    send_request "GET /tasks/api" "success" "GET" "/tasks/api"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    send_request "GET /tasks/api" "failure" "GET" "/tasks/api?fail=true"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed GET /tasks/api"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    task_id="$(task_id_for_index "${i}")"
    send_request "GET /tasks/api/{id}" "success" "GET" "/tasks/api/${task_id}"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    send_request "GET /tasks/api/{id}" "failure" "GET" "/tasks/api/999999999"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed GET /tasks/api/{id}"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    task_id="$(task_id_for_index "${i}")"
    payload=$(printf '{"title":"load-cycle-%s-task-%s-updated","description":"Updated load cycle %s request %s","completed":true}' "${cycle}" "${i}" "${cycle}" "${i}")
    send_request "PUT /tasks/api/{id}" "success" "PUT" "/tasks/api/${task_id}" "${payload}"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    payload=$(printf '{"title":"load-cycle-%s-missing-%s","description":"Missing task update","completed":true}' "${cycle}" "${i}")
    send_request "PUT /tasks/api/{id}" "failure" "PUT" "/tasks/api/999999999" "${payload}"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed PUT /tasks/api/{id}"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    task_id="$(task_id_for_index "${i}")"
    send_request "DELETE /tasks/api/{id}" "success" "DELETE" "/tasks/api/${task_id}"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    send_request "DELETE /tasks/api/{id}" "failure" "DELETE" "/tasks/api/999999999"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed DELETE /tasks/api/{id}"

  i=1
  while [ "${i}" -le "${SUCCESS_REQUESTS_PER_API}" ]; do
    send_request "GET /tasks/api/test/bad-query" "success" "GET" "/tasks/api/test/bad-query?fail=false"
    i=$((i + 1))
  done
  i=1
  while [ "${i}" -le "${FAILED_REQUESTS_PER_API}" ]; do
    send_request "GET /tasks/api/test/bad-query" "failure" "GET" "/tasks/api/test/bad-query?fail=true"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed GET /tasks/api/test/bad-query"

  i=1
  while [ "${i}" -le "${SLOW_REQUESTS_PER_CYCLE}" ]; do
    send_slow_request "${i}"
    i=$((i + 1))
  done
  echo "Cycle ${cycle}: completed slow DB requests"

  elapsed=$(( $(date +%s) - cycle_start ))
  sleep_seconds=$((CYCLE_SECONDS - elapsed))

  echo "Completed load cycle ${cycle} with ${unexpected_results} unexpected responses"
  if [ "${sleep_seconds}" -gt 0 ]; then
    sleep "${sleep_seconds}"
  fi
done
