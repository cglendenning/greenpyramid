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
    if [[ "$device_id" == emulator-* ]]; then
      # Android 12L/14 can show a taskbar education dialog over a freshly
      # launched tablet app. Detect its large white panel from a screenshot
      # before capture; tap only when that panel is present.
      sleep 1
      probe="$output_dir/.probe.png"
      adb -s "$device_id" exec-out screencap -p > "$probe" 2>/dev/null || true
      if /usr/bin/python3 - "$probe" <<'PY'
from pathlib import Path
import sys
try:
    from PIL import Image
    image = Image.open(Path(sys.argv[1])).convert('RGB')
    pixels = [image.getpixel((x, y)) for x in range(820, 1740, 80) for y in range(300, 1160, 80)]
    bright = sum(1 for r, g, b in pixels if r > 225 and g > 225 and b > 225)
    raise SystemExit(0 if bright / len(pixels) > 0.35 else 1)
except Exception:
    raise SystemExit(1)
PY
      then
        adb -s "$device_id" shell input tap 1280 1040 >/dev/null 2>&1 || true
        sleep 1
      fi
      if adb -s "$device_id" exec-out screencap -p > "$output_dir/$name.png" 2>/dev/null && [[ -s "$output_dir/$name.png" ]]; then
        touch "$ack_dir/$name"
      else
        printf 'Screenshot capture failed for %s\n' "$name" >&2
      fi
      rm -f "$probe"
    elif flutter screenshot -d "$device_id" -o "$output_dir/$name.png" >/dev/null 2>&1 && [[ -s "$output_dir/$name.png" ]]; then
      touch "$ack_dir/$name"
    else
      printf 'Screenshot capture failed for %s\n' "$name" >&2
    fi
  fi
done
