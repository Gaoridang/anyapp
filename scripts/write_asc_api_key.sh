#!/usr/bin/env bash
set -euo pipefail

# Writes App Store Connect API key (.p8) from base64 env vars.
# Used by GitHub Actions TestFlight workflow and local verification.

: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_KEY_CONTENT_BASE64:?ASC_KEY_CONTENT_BASE64 is required}"

ASC_KEY_ID="$(printf '%s' "$ASC_KEY_ID" | tr -d '[:space:]')"
CLEANED_B64="$(printf '%s' "$ASC_KEY_CONTENT_BASE64" | tr -d '[:space:]')"

if [[ -z "$ASC_KEY_ID" || -z "$CLEANED_B64" ]]; then
  echo "ASC_KEY_ID or ASC_KEY_CONTENT_BASE64 is empty after sanitization." >&2
  exit 1
fi

KEY_DIR="${ASC_KEY_DIR:-$HOME/.appstoreconnect/private_keys}"
mkdir -p "$KEY_DIR"
KEY_PATH="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"

printf '%s' "$CLEANED_B64" | base64 --decode > "$KEY_PATH"
chmod 600 "$KEY_PATH"

if ! openssl pkey -in "$KEY_PATH" -noout >/dev/null 2>&1; then
  echo "Decoded key at $KEY_PATH is not a valid private key." >&2
  exit 1
fi

if ! grep -q "BEGIN PRIVATE KEY" "$KEY_PATH"; then
  echo "Decoded key at $KEY_PATH is missing PKCS#8 header." >&2
  exit 1
fi

echo "ASC_KEY_PATH=$KEY_PATH"