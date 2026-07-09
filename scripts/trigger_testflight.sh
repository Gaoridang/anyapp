#!/usr/bin/env bash
set -euo pipefail

# Triggers the TestFlight workflow via repository_dispatch.
# Prefer this over `gh workflow run` — Cloud Agent tokens often lack workflow_dispatch permission.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_NUMBER="${1:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

gh api "repos/${REPO}/dispatches" \
  -f event_type=deploy-testflight \
  -f "client_payload[build_number]=${BUILD_NUMBER}"

echo "Triggered TestFlight deploy on ${REPO}."
echo "Check status: gh run list --workflow=testflight.yml --limit 3"
