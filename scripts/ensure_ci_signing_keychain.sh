#!/bin/bash
# Makes iOS release codesigning work non-interactively (no GUI keychain
# prompt, no Mac login password) for both greenpyramid and admin release
# builds, in a plain Claude Code session with no Window Server access.
#
# Root cause this works around: the login keychain can end up with several
# copies of "Apple Distribution: Craig Glendenning" whose private-key ACLs
# were only ever granted interactively (a one-time "Always Allow" click),
# which a non-interactive session can't get past -- codesign fails with
# errSecInternalComponent even on a trivial file, regardless of which
# keychain/copy is targeted. Any previously created /tmp/*.keychain-db
# workaround stops working the moment it locks again (reboot, idle
# timeout) because nothing recorded the password used to create it.
#
# Fix: rebuild a small dedicated keychain every time from a *portable*,
# passphrase-free copy of the signing key -- ~/Desktop/certs/distribution.cer
# + distribution_key.pem (an unencrypted PEM exported previously; confirm
# with `openssl rsa -in distribution_key.pem -check -noout -passin pass:`)
# -- with a fixed local-only password, then explicitly grant the codesign
# tool ACL access via `security set-key-partition-list`. That single API
# call is what replaces the interactive "Always Allow" click, and it is
# fully scriptable. The keychain is ours to recreate any time, so a fixed
# password here is fine: it protects nothing the account doesn't already
# expose via the plaintext .cer/.pem pair sitting next to it.
#
# Usage: source this file (or run it) before `flutter build ipa`:
#   scripts/ensure_ci_signing_keychain.sh
# It is idempotent -- safe to re-run every session.
set -euo pipefail

KEYCHAIN_PATH="/tmp/greenpyramid-ci.keychain-db"
KEYCHAIN_PASSWORD="greenpyramid-ci-local-only"
CERT_DIR="$HOME/Desktop/certs"
CERT_FILE="$CERT_DIR/distribution.cer"
KEY_FILE="$CERT_DIR/distribution_key.pem"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "ERROR: expected $CERT_FILE and $KEY_FILE (portable, passphrase-free" >&2
  echo "distribution certificate + key) -- not found. Export a fresh pair from" >&2
  echo "Apple Developer > Certificates if these are missing, and confirm the" >&2
  echo "key has no passphrase: openssl rsa -in \"$KEY_FILE\" -check -noout -passin pass:" >&2
  exit 1
fi

# Recreate fresh every run rather than trying to detect/repair a stale one --
# cheap, and avoids ever debugging "which stale state is this keychain in."
security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

security import "$KEY_FILE" -k "$KEYCHAIN_PATH" -A
security import "$CERT_FILE" -k "$KEYCHAIN_PATH" -A

# This is the step that actually replaces the interactive "Always Allow"
# dialog: without it, codesign/xcodebuild fail with errSecInternalComponent
# in any session that isn't attached to a Window Server that can show that
# dialog (which includes a background Claude Code job).
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

# Put it first in the search list (keep everything already there) so
# xcodebuild's internal codesign calls -- which pick an identity by name
# from the ambient search list, not a --keychain flag we control -- find
# this known-good copy instead of a broken duplicate elsewhere.
EXISTING_KEYCHAINS=$(security list-keychains -d user | sed 's/^ *"//;s/"$//' | grep -v "^${KEYCHAIN_PATH}$" || true)
security list-keychains -d user -s "$KEYCHAIN_PATH" $EXISTING_KEYCHAINS

# Reference the identity by its SHA-1 hash, not its display name: several
# other copies of a same-named "Apple Distribution: Craig Glendenning"
# identity can exist in other keychains (stale imports from past sessions),
# and codesign refuses an ambiguous name match even when scoped with
# --keychain. The hash is unique to this exact key pair.
IDENTITY_HASH=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep "Apple Distribution" | head -1 | awk '{print $2}')
if [ -z "$IDENTITY_HASH" ]; then
  echo "ERROR: no Apple Distribution identity found after import." >&2
  exit 1
fi

echo "Verifying codesign can use identity $IDENTITY_HASH non-interactively..."
TEST_FILE=$(mktemp)
echo test > "$TEST_FILE"
if ! codesign -s "$IDENTITY_HASH" --keychain "$KEYCHAIN_PATH" --force "$TEST_FILE" 2>&1; then
  echo "ERROR: codesign still failed against the freshly built keychain." >&2
  echo "This means the problem is not a stale/locked keychain -- stop and" >&2
  echo "investigate (e.g. a genuinely revoked/expired certificate) rather" >&2
  echo "than re-running this script again." >&2
  rm -f "$TEST_FILE"
  exit 1
fi
rm -f "$TEST_FILE"
echo "OK: $KEYCHAIN_PATH is ready for non-interactive release signing."
