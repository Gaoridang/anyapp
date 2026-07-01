#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

cd "$ROOT"

TEST_KEY_ID="TESTKEY123"
TEST_KEY_DIR="$SCRATCH/keys"

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 -out "$SCRATCH/source.pem" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$SCRATCH/source.pem" -out "$SCRATCH/AuthKey_${TEST_KEY_ID}.p8"
TEST_B64="$(base64 -i "$SCRATCH/AuthKey_${TEST_KEY_ID}.p8" | tr -d '[:space:]')"

OUTPUT="$(
  ASC_KEY_ID="$TEST_KEY_ID" \
  ASC_KEY_CONTENT_BASE64="$TEST_B64" \
  ASC_KEY_DIR="$TEST_KEY_DIR" \
  "$ROOT/scripts/write_asc_api_key.sh"
)"

EXPECTED_PATH="$TEST_KEY_DIR/AuthKey_${TEST_KEY_ID}.p8"
if [[ "$OUTPUT" != "ASC_KEY_PATH=$EXPECTED_PATH" ]]; then
  echo "Unexpected script output: $OUTPUT" >&2
  exit 1
fi

if [[ ! -f "$EXPECTED_PATH" ]]; then
  echo "Expected key file was not created." >&2
  exit 1
fi

if ! openssl pkey -in "$EXPECTED_PATH" -noout >/dev/null 2>&1; then
  echo "Written key is not valid." >&2
  exit 1
fi

# Verify whitespace-tolerant decoding
PADDED_B64="$(printf '%s\n\n' "$TEST_B64")"
OUTPUT2="$(
  ASC_KEY_ID="$TEST_KEY_ID" \
  ASC_KEY_CONTENT_BASE64="$PADDED_B64" \
  ASC_KEY_DIR="$SCRATCH/keys2" \
  "$ROOT/scripts/write_asc_api_key.sh"
)"
EXPECTED_PATH2="$SCRATCH/keys2/AuthKey_${TEST_KEY_ID}.p8"
if [[ "$OUTPUT2" != "ASC_KEY_PATH=$EXPECTED_PATH2" ]]; then
  echo "Whitespace-tolerant decode failed: $OUTPUT2" >&2
  exit 1
fi

echo "write_asc_api_key.sh tests passed."