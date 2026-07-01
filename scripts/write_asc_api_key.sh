#!/usr/bin/env bash
set -euo pipefail

# Writes App Store Connect API key (.p8) from base64 env vars.
# Used by GitHub Actions TestFlight workflow and local verification.

: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_KEY_CONTENT_BASE64:?ASC_KEY_CONTENT_BASE64 is required}"

ASC_KEY_ID="$(printf '%s' "$ASC_KEY_ID" | tr -d '[:space:]')"
KEY_MATERIAL="$(printf '%s' "$ASC_KEY_CONTENT_BASE64")"

if [[ -z "$ASC_KEY_ID" || -z "$KEY_MATERIAL" ]]; then
  echo "ASC_KEY_ID or ASC_KEY_CONTENT_BASE64 is empty." >&2
  exit 1
fi

KEY_DIR="${ASC_KEY_DIR:-$HOME/.appstoreconnect/private_keys}"
mkdir -p "$KEY_DIR"
KEY_PATH="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"

key_is_valid() {
  openssl pkey -in "$KEY_PATH" -noout >/dev/null 2>&1 \
    || openssl pkey -inform DER -in "$KEY_PATH" -noout >/dev/null 2>&1
}

write_decoded_key() {
  local candidate="$1"
  if ! printf '%s' "$candidate" | base64 --decode > "$KEY_PATH" 2>/dev/null; then
    return 1
  fi
  key_is_valid
}

if printf '%s' "$KEY_MATERIAL" | grep -q "BEGIN .*PRIVATE KEY"; then
  printf '%s' "$KEY_MATERIAL" > "$KEY_PATH"
elif write_decoded_key "$(printf '%s' "$KEY_MATERIAL" | tr -d '[:space:]')"; then
  :
else
  rm -f "$KEY_PATH"
  echo "ASC_KEY_CONTENT_BASE64 must be base64-encoded .p8 content or raw PEM." >&2
  exit 1
fi

chmod 600 "$KEY_PATH"

if ! key_is_valid; then
  echo "Key at $KEY_PATH is not a valid private key." >&2
  exit 1
fi

# xcodebuild expects PEM; normalize DER or non-PEM encodings in place.
if ! grep -Eq "BEGIN (EC )?PRIVATE KEY" "$KEY_PATH"; then
  NORMALIZED="$(mktemp)"
  if openssl pkey -in "$KEY_PATH" -out "$NORMALIZED" >/dev/null 2>&1 \
    || openssl pkey -inform DER -in "$KEY_PATH" -out "$NORMALIZED" >/dev/null 2>&1; then
    mv "$NORMALIZED" "$KEY_PATH"
    chmod 600 "$KEY_PATH"
  else
    rm -f "$NORMALIZED"
    echo "Key at $KEY_PATH could not be normalized to PEM." >&2
    exit 1
  fi
fi

echo "ASC_KEY_PATH=$KEY_PATH"