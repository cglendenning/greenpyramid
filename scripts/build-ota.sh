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
    # The Runner Release config signs automatically for App Store archives.
    # An OTA build instead needs manual ad-hoc signing pinned to the CI
    # keychain's distribution cert by SHA-1 (same-named certs exist), so it
    # is supplied through an optional xcconfig that exists only for this run.
    OTA_SIGNING_XCCONFIG="ios/Flutter/OTASigning.xcconfig"
    restore_keychains() {
      rm -f "$OTA_SIGNING_XCCONFIG"
      if [ "${#ORIGINAL_KEYCHAINS[@]}" -gt 0 ]; then
        security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
      fi
    }
    trap restore_keychains EXIT INT TERM
    bash scripts/ensure_ci_signing_keychain.sh
    cat > "$OTA_SIGNING_XCCONFIG" <<EOF
GP_OTA_CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = 66F1F59CE546829AA563FE01BF325E9BC197584A
CODE_SIGN_IDENTITY[sdk=iphoneos*] = 66F1F59CE546829AA563FE01BF325E9BC197584A
PROVISIONING_PROFILE_SPECIFIER = Green Pyramid Consumer Ad Hoc CI
OTHER_CODE_SIGN_FLAGS = --keychain $CI_KEYCHAIN_PATH
EOF
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
