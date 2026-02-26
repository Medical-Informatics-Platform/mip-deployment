#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

docker compose down -v
docker compose up -d

endpoint="http://172.17.0.1:8080/services/data-models"
max_attempts=30

for attempt in $(seq 1 "${max_attempts}"); do
  response="$(curl -fsS --max-time 5 "${endpoint}" 2>/dev/null || true)"
  if printf '%s' "${response}" | grep -q '"code"[[:space:]]*:[[:space:]]*"dementia_longitudinal"' \
    && printf '%s' "${response}" | grep -q '"code"[[:space:]]*:[[:space:]]*"dementia"' \
    && printf '%s' "${response}" | grep -q '"code"[[:space:]]*:[[:space:]]*"mentalhealth"' \
    && printf '%s' "${response}" | grep -q '"code"[[:space:]]*:[[:space:]]*"tbi"'
  then
    echo "Data models check passed: expected codes are available."
    echo "You can see the MIP at 172.17.0.1"
    exit 0
  fi
  sleep 2
done

echo "Error: expected data model codes were not found at ${endpoint}." >&2
exit 1
