#!/bin/bash
# Usage: scripts/serve-ota.sh
# Serves the freshly built IPA over a Cloudflare tunnel and prints an
# itms-services:// OTA install link for the phone. Mirrors the goal-executor
# OTA workflow. Run `flutter build ipa --export-options-plist ios/ExportOptions.plist`
# first; this script refuses to serve if no IPA is present.

IPA_DIR="/Users/craig/greenpyramid/build/ios/ipa"
BUNDLE_ID="com.cglendenning.lifeops"
TITLE="Green Pyramid"
PORT=8765

# Resolve the built IPA (flutter names it after the app; don't hard-code).
IPA_PATH=$(ls -t "${IPA_DIR}"/*.ipa 2>/dev/null | head -1)
if [ -z "$IPA_PATH" ]; then
  echo "ERROR: no .ipa in ${IPA_DIR} — run flutter build ipa first" >&2
  exit 1
fi
IPA_NAME=$(basename "$IPA_PATH")

# Kill any leftover server or tunnel from a previous run.
lsof -ti:${PORT} | xargs kill -9 2>/dev/null || true
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1

# Start HTTP server and tunnel.
python3 -m http.server ${PORT} --directory "${IPA_DIR}" &>/tmp/gp_ipa_server.log &
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

# Write the manifest with the live URL.
cat > "${IPA_DIR}/manifest.plist" << EOF
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
          <string>${TUNNEL_URL}/${IPA_NAME}</string>
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

# Confirm the IPA is reachable before printing the link.
HTTP_CODE="000"
for i in $(seq 30); do
  HTTP_CODE=$(curl -s --max-time 10 \
    --resolve "${TUNNEL_HOST}:443:${TUNNEL_IP}" \
    "${TUNNEL_URL}/${IPA_NAME}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null)
  [ "$HTTP_CODE" = "200" ] && break
  sleep 1
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: IPA returned HTTP ${HTTP_CODE} via tunnel after 30 s" >&2
  exit 1
fi

echo "IPA: ${IPA_NAME}"
echo "itms-services://?action=download-manifest&url=${TUNNEL_URL}/manifest.plist"

# Keep the HTTP server and tunnel alive (they are backgrounded above) until
# this script is stopped, so the OTA link stays valid while the user installs.
wait
