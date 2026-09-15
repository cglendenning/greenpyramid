#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-fast-check}"
case "$MODE" in
  fast-check)
    exec flutter build ios --release --no-codesign
    ;;
  release-ipa)
    BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
    exec flutter build ipa --release \
      --build-name="${BUILD_NAME:-1.0.0}" \
      --build-number="$BUILD_NUMBER" \
      --export-options-plist=ios/ExportOptions.plist
    ;;
  *)
    echo "Usage: $0 fast-check|release-ipa" >&2
    exit 2
    ;;
esac
