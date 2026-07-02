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
check "workflow is manual only" "! grep -q '^  push:' .github/workflows/testflight.yml"
check "workflow has workflow_dispatch" "grep -q 'workflow_dispatch' .github/workflows/testflight.yml"
check "workflow supports repository_dispatch" "grep -q 'repository_dispatch' .github/workflows/testflight.yml"
check "workflow accepts build_number input" "grep -q 'build_number:' .github/workflows/testflight.yml"
check "workflow caches DerivedData" "grep -q 'Developer/Xcode/DerivedData' .github/workflows/testflight.yml"
check "workflow uses write_asc_api_key script" "grep -q 'scripts/write_asc_api_key.sh' .github/workflows/testflight.yml"
check "ci-verify workflow exists" "test -f .github/workflows/ci-verify.yml"
check "fastlane beta lane exists" "grep -q 'lane :beta' fastlane/Fastfile"
check "fastlane passes xcode auth via xcargs" "grep -q 'authenticationKeyPath' fastlane/Fastfile"
check "fastlane skips build processing wait" "grep -q 'skip_waiting_for_build_processing: true' fastlane/Fastfile"
check "fastlane handles upload limit" "grep -q '90382' fastlane/Fastfile"
check "fastlane accepts target build number" "grep -q 'TARGET_BUILD_NUMBER' fastlane/Fastfile"
check "fastlane disables previews in CI" "grep -q 'ENABLE_PREVIEWS=NO' fastlane/Fastfile"
check "export compliance configured" "grep -q 'ITSAppUsesNonExemptEncryption' anyapp.xcodeproj/project.pbxproj"
check "fastlane sets encryption compliance" "grep -q 'uses_non_exempt_encryption: false' fastlane/Fastfile"
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