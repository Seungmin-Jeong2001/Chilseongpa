#!/usr/bin/env bash

set -euo pipefail

if [ -f .env.testk6 ]; then
  echo "Loading variables from .env.testk6..."
  set -a
  source .env.testk6
  set +a
fi

# 필수 변수 검증
if [ -z "${TARGET_BASE_URL:-}" ]; then
  echo "ERROR: TARGET_BASE_URL is required"
  exit 1
fi

if [ -z "${TARGET_API_PATH:-}" ]; then
  echo "ERROR: TARGET_API_PATH is required"
  exit 1
fi

IMAGE_NAME="chilseongpa-k6"
WORK_DIR_HOST="$(pwd)"
RESULTS_DIR_HOST="${WORK_DIR_HOST}/results"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="results/summary_${TIMESTAMP}.json"

mkdir -p "${RESULTS_DIR_HOST}"

echo "Target: ${TARGET_BASE_URL}${TARGET_API_PATH}"

echo "[1/2] Build k6 image"
docker build -t "${IMAGE_NAME}" .

echo "[2/2] Run k6 test"
docker run --rm \
  --ulimit nofile=65535:65535 \
  -v "${WORK_DIR_HOST}:/work" \
  -w /work \
  -e TARGET_BASE_URL="${TARGET_BASE_URL}" \
  -e TARGET_API_PATH="${TARGET_API_PATH}" \
  -e HTTP_METHOD="${HTTP_METHOD:-GET}" \
  -e VUS="${VUS:-300}" \
  -e DURATION="${DURATION:-2m}" \
  -e STAGES_JSON="${STAGES_JSON:-}" \
  -e REQUEST_INTERVAL_MS="${REQUEST_INTERVAL_MS:-0}" \
  -e THRESHOLD_P95_MS="${THRESHOLD_P95_MS:-3000}" \
  -e CONTENT_TYPE="${CONTENT_TYPE:-application/json}" \
  -e HEADERS_JSON="${HEADERS_JSON:-}" \
  -e BODY_JSON="${BODY_JSON:-}" \
  -e WANT_503="${WANT_503:-true}" \
  "${IMAGE_NAME}" \
  run scenarios/single_api_load.js \
  --dns-ttl 0s \
  --summary-export "${SUMMARY_FILE}"

echo
echo "Done"
echo "Summary: ${RESULTS_DIR_HOST}/summary_${TIMESTAMP}.json"