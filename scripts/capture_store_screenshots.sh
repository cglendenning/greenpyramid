#!/bin/bash
set -euo pipefail

device_id="${1:?usage: $0 DEVICE_ID}"
output_dir="${2:-screenshots/current-ios}"
ack_dir="/private/tmp/gp-shot-acks"
mkdir -p "$ack_dir" "$output_dir"

rm -f "$ack_dir"/*

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$device_id" 2>&1 |
while IFS= read -r line; do
  printf '%s\n' "$line"
  if [[ "$line" == *MARKER_SHOT:* ]]; then
    name="${line##*MARKER_SHOT:}"
    name="${name%%$'\r'*}"
    if flutter screenshot -d "$device_id" -o "$output_dir/$name.png" >/dev/null 2>&1 && [[ -s "$output_dir/$name.png" ]]; then
      touch "$ack_dir/$name"
    else
      printf 'Screenshot capture failed for %s\n' "$name" >&2
    fi
  fi
done
