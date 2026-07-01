#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

errors=0

check() {
  if ! eval "$2"; then
    echo "FAIL: $1" >&2
    errors=$((errors + 1))
  else
    echo "OK: $1"
  fi
}

check "workflow exists" "test -f .github/workflows/testflight.yml"
check "workflow has push trigger on main" "grep -q 'branches: \\[main\\]' .github/workflows/testflight.yml"
check "workflow has workflow_dispatch" "grep -q 'workflow_dispatch' .github/workflows/testflight.yml"
check "workflow uses write_asc_api_key script" "grep -q 'scripts/write_asc_api_key.sh' .github/workflows/testflight.yml"
check "fastlane beta lane exists" "grep -q 'lane :beta' fastlane/Fastfile"
check "fastlane passes xcode auth via xcargs" "grep -q 'authenticationKeyPath' fastlane/Fastfile"
check "bundle id configured" "grep -q 'com.ijaejun.anyapp' fastlane/Appfile"
check "team id configured" "grep -q 'T5CBR768BM' fastlane/Appfile"
check "Gemfile.lock present" "test -f Gemfile.lock"
check "app icon 120px present" "test -f anyapp/Assets.xcassets/AppIcon.appiconset/AppIcon-120.png"
check "app icon 1024px present" "test -f anyapp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

if [[ "$errors" -gt 0 ]]; then
  echo "$errors check(s) failed." >&2
  exit 1
fi

echo "All CI configuration checks passed."