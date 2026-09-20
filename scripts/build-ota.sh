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
    CI_KEYCHAIN_PATH="/tmp/greenpyramid-ci.keychain-db"
    # Xcode can search every keychain in the user's search list even when the
    # export options pin the certificate hash.  A stale locked keychain then
    # opens a GUI password prompt.  Save and restore the user's list, but make
    # the build itself see only the verified CI keychain.
    ORIGINAL_KEYCHAINS=()
    while IFS= read -r keychain; do
      ORIGINAL_KEYCHAINS+=("$keychain")
    done < <(security list-keychains -d user | sed 's/^ *"//; s/"$//')
    restore_keychains() {
      if [ "${#ORIGINAL_KEYCHAINS[@]}" -gt 0 ]; then
        security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
      fi
    }
    trap restore_keychains EXIT INT TERM
    bash scripts/ensure_ci_signing_keychain.sh
    security list-keychains -d user -s "$CI_KEYCHAIN_PATH"
    export OTHER_CODE_SIGN_FLAGS="--keychain $CI_KEYCHAIN_PATH"
    flutter build ipa --release \
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
