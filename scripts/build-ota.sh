#!/bin/bash
# Build a production-signed artifact for OTA distribution.
#
# This script intentionally does not pass FORCE_APP_CHECK_DEBUG. iOS OTA
# builds use the signed production App Attest entitlement; debug App Check
# tokens are not appropriate for a delivered IPA.

set -euo pipefail

MODE="${1:-ios}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

case "$MODE" in
  ios)
    exec flutter build ipa --release \
      --export-options-plist ios/ExportOptions.plist
    ;;
  android)
    exec flutter build apk --release
    ;;
  *)
    echo "ERROR: unknown mode '$MODE' — use ios or android" >&2
    exit 1
    ;;
esac
