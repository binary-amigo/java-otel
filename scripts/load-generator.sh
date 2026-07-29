#!/bin/sh
set -eu

APP_URL="${APP_URL:-http://app:8050}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
BAD_QUERY_EVERY="${BAD_QUERY_EVERY:-10}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-5}"

echo "Waiting for ${APP_URL}/tasks/api"
until curl -fsS --max-time "${REQUEST_TIMEOUT}" "${APP_URL}/tasks/api" >/dev/null 2>&1; do
  sleep 2
done

echo "Starting continuous load generation"
iteration=0

while true; do
  iteration=$((iteration + 1))
  title="load-task-${iteration}"
  payload=$(printf '{"title":"%s","description":"Generated load iteration %s","completed":false}' "${title}" "${iteration}")

  response=$(curl -fsS --max-time "${REQUEST_TIMEOUT}" \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    "${APP_URL}/tasks/api" || true)

  task_id=$(printf "%s" "${response}" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')

  curl -fsS --max-time "${REQUEST_TIMEOUT}" "${APP_URL}/tasks/api" >/dev/null || true

  if [ -n "${task_id}" ]; then
    update_payload=$(printf '{"title":"%s-updated","description":"Updated load iteration %s","completed":true}' "${title}" "${iteration}")

    curl -fsS --max-time "${REQUEST_TIMEOUT}" \
      -H "Content-Type: application/json" \
      -X PUT \
      -d "${update_payload}" \
      "${APP_URL}/tasks/api/${task_id}" >/dev/null || true

    curl -fsS --max-time "${REQUEST_TIMEOUT}" "${APP_URL}/tasks/api/${task_id}" >/dev/null || true
    curl -fsS --max-time "${REQUEST_TIMEOUT}" -X DELETE "${APP_URL}/tasks/api/${task_id}" >/dev/null || true
  fi

  if [ $((iteration % BAD_QUERY_EVERY)) -eq 0 ]; then
    curl -fsS --max-time "${REQUEST_TIMEOUT}" "${APP_URL}/tasks/api/test/bad-query" >/dev/null || true
  fi

  echo "Completed load iteration ${iteration}"
  sleep "${SLEEP_SECONDS}"
done
