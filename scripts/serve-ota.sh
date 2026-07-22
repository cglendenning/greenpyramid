#!/bin/bash
# Usage: scripts/serve-ota.sh [ios|android]
# Serves the freshly built IPA or APK over a Cloudflare tunnel and prints an
# OTA install link for the phone. Mirrors the goal-executor OTA workflow.
# ios (default): run `flutter build ipa --export-options-plist ios/ExportOptions.plist`
#   first; prints an itms-services:// manifest link.
# android: run `flutter build apk --release` first; prints a direct APK link.
# Refuses to serve if the expected build artifact is not present.

MODE="${1:-ios}"
BUNDLE_ID="com.cglendenning.lifeops"
TITLE="Green Pyramid"
PORT=8765

case "$MODE" in
  ios)
    SERVE_DIR="/Users/craig/greenpyramid/build/ios/ipa"
    ARTIFACT=$(ls -t "${SERVE_DIR}"/*.ipa 2>/dev/null | head -1)
    [ -z "$ARTIFACT" ] && { echo "ERROR: no .ipa in ${SERVE_DIR} — run flutter build ipa first" >&2; exit 1; }
    ;;
  android)
    SERVE_DIR="/Users/craig/greenpyramid/build/app/outputs/flutter-apk"
    ARTIFACT=$(ls -t "${SERVE_DIR}"/*-release.apk 2>/dev/null | head -1)
    [ -z "$ARTIFACT" ] && { echo "ERROR: no release .apk in ${SERVE_DIR} — run flutter build apk --release first" >&2; exit 1; }
    ;;
  *)
    echo "ERROR: unknown mode '${MODE}' — use ios or android" >&2
    exit 1
    ;;
esac
ARTIFACT_NAME=$(basename "$ARTIFACT")

# Kill any leftover server or tunnel from a previous run.
lsof -ti:${PORT} | xargs kill -9 2>/dev/null || true
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1

# Start HTTP server and tunnel.
python3 -m http.server ${PORT} --directory "${SERVE_DIR}" &>/tmp/gp_ota_server.log &
cloudflared tunnel --url http://localhost:${PORT} --no-autoupdate &>/tmp/gp_cloudflared.log &

# Extract the tunnel URL as soon as it appears in the log.
TUNNEL_URL=""
for i in $(seq 60); do
  TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/gp_cloudflared.log 2>/dev/null | head -1 || true)
  [ -n "$TUNNEL_URL" ] && break
  sleep 1
done

if [ -z "$TUNNEL_URL" ]; then
  echo "ERROR: tunnel URL not found after 60 s — check /tmp/gp_cloudflared.log" >&2
  exit 1
fi

if [ "$MODE" = "ios" ]; then
  # Write the manifest with the live URL.
  cat > "${SERVE_DIR}/manifest.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${TUNNEL_URL}/${ARTIFACT_NAME}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${BUNDLE_ID}</string>
        <key>bundle-version</key>
        <string>$(date +%s)</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${TITLE}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF
fi

# macOS getaddrinfo is unreliable for new trycloudflare.com subdomains when a
# VPN/MagicDNS is active. Resolve via dig and pass --resolve to curl so we
# bypass the system resolver. Retry — DNS propagates a few seconds late.
TUNNEL_HOST=$(echo "$TUNNEL_URL" | sed 's|https://||')
TUNNEL_IP=""
for i in $(seq 30); do
  TUNNEL_IP=$(dig +short "$TUNNEL_HOST" 2>/dev/null | grep -E '^[0-9]+\.' | head -1 || true)
  [ -n "$TUNNEL_IP" ] && break
  sleep 1
done

if [ -z "$TUNNEL_IP" ]; then
  echo "ERROR: could not resolve $TUNNEL_HOST via dig after 30 s" >&2
  exit 1
fi

# Confirm the artifact is reachable before printing the link.
HTTP_CODE="000"
for i in $(seq 30); do
  HTTP_CODE=$(curl -s --max-time 10 \
    --resolve "${TUNNEL_HOST}:443:${TUNNEL_IP}" \
    "${TUNNEL_URL}/${ARTIFACT_NAME}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null)
  [ "$HTTP_CODE" = "200" ] && break
  sleep 1
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: ${ARTIFACT_NAME} returned HTTP ${HTTP_CODE} via tunnel after 30 s" >&2
  exit 1
fi

echo "ARTIFACT: ${ARTIFACT_NAME}"
if [ "$MODE" = "ios" ]; then
  echo "itms-services://?action=download-manifest&url=${TUNNEL_URL}/manifest.plist"
else
  echo "${TUNNEL_URL}/${ARTIFACT_NAME}"
fi

# Keep the HTTP server and tunnel alive (they are backgrounded above) until
# this script is stopped, so the OTA link stays valid while the user installs.
wait
