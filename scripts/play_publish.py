#!/usr/bin/env python3
"""Google Play Developer API release helper for Green Pyramid.

Parallel to asc_release.py (App Store). Auth: a Play Developer service-account
JSON key (Cloud Console) whose email is invited into Play Console under
Users & permissions.

Subcommands:
  verify KEY_JSON
      Read-only: open a throwaway edit, list tracks + current production
      version codes, then delete the edit. Proves auth + app access without
      changing anything.
  check-upload-key KEY_JSON AAB
      Non-destructive: open an edit, upload AAB (forces Play to validate its
      signing certificate), then delete the edit WITHOUT committing. A
      successful upload means the upload key is accepted (reset approved);
      a signing-cert error means it is not yet in effect. Ships nothing.
  publish KEY_JSON AAB NOTES_FILE [--track production]
      Upload AAB to the track (default production) as a completed release with
      NOTES_FILE as the en-US release notes, then commit the edit (goes live to
      the track's rollout). Prints the uploaded version code.
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

PACKAGE = "com.cglendenning.life_ops"  # Android applicationId (note: iOS bundle id is com.cglendenning.lifeops, no underscore)
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def access_token(key_path: str) -> str:
    sa = json.load(open(key_path))
    now = int(time.time())
    assertion = jwt.encode(
        {"iss": sa["client_email"], "scope": SCOPE, "aud": sa["token_uri"],
         "iat": now, "exp": now + 3600},
        sa["private_key"], algorithm="RS256")
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion}).encode()
    req = urllib.request.Request(sa["token_uri"], data=body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())["access_token"]
    except urllib.error.HTTPError as e:
        raise SystemExit(f"token exchange failed HTTP {e.code}:\n{e.read().decode()}")


def call(token: str, method: str, url: str, body=None, raw=None,
         content_type="application/json") -> dict:
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    data = None
    if raw is not None:
        data = raw
        req.add_header("Content-Type", content_type)
    elif body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as resp:
            payload = resp.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} on {method} {url}:\n{e.read().decode()}")


def verify(key_path: str) -> None:
    token = access_token(key_path)
    edit = call(token, "POST", f"{API}/applications/{PACKAGE}/edits")
    eid = edit["id"]
    print(f"auth OK; opened edit {eid} on {PACKAGE}")
    tracks = call(token, "GET", f"{API}/applications/{PACKAGE}/edits/{eid}/tracks")
    for t in tracks.get("tracks", []):
        codes = [vc for r in t.get("releases", []) for vc in r.get("versionCodes", [])]
        print(f"  track {t['track']}: version codes {codes or '(none)'}")
    call(token, "DELETE", f"{API}/applications/{PACKAGE}/edits/{eid}")
    print("deleted throwaway edit; no changes made")


def check_upload_key(key_path: str, aab: str) -> None:
    token = access_token(key_path)
    edit = call(token, "POST", f"{API}/applications/{PACKAGE}/edits")
    eid = edit["id"]
    print(f"opened edit {eid}; uploading bundle to validate signing cert...")
    blob = open(aab, "rb").read()
    try:
        up = call(token, "POST",
                  f"{UPLOAD}/applications/{PACKAGE}/edits/{eid}/bundles?uploadType=media",
                  raw=blob, content_type="application/octet-stream")
    finally:
        # Always discard the edit so this check never ships anything.
        call(token, "DELETE", f"{API}/applications/{PACKAGE}/edits/{eid}")
        print("deleted edit; nothing committed")
    print(f"UPLOAD KEY ACCEPTED: reset is approved. "
          f"versionCode={up['versionCode']} sha256={up.get('sha256','')[:16]}...")


def publish(key_path: str, aab: str, notes_file: str, track: str) -> None:
    notes = open(notes_file).read().strip()
    token = access_token(key_path)
    edit = call(token, "POST", f"{API}/applications/{PACKAGE}/edits")
    eid = edit["id"]
    print(f"opened edit {eid}")
    blob = open(aab, "rb").read()
    up = call(token, "POST",
              f"{UPLOAD}/applications/{PACKAGE}/edits/{eid}/bundles?uploadType=media",
              raw=blob, content_type="application/octet-stream")
    vc = up["versionCode"]
    print(f"uploaded bundle: versionCode={vc} sha256={up.get('sha256','')[:16]}...")
    call(token, "PUT",
         f"{API}/applications/{PACKAGE}/edits/{eid}/tracks/{track}",
         body={"track": track,
               "releases": [{"versionCodes": [str(vc)], "status": "completed",
                             "releaseNotes": [{"language": "en-US", "text": notes}]}]})
    print(f"assigned versionCode {vc} to '{track}' (status completed)")
    call(token, "POST", f"{API}/applications/{PACKAGE}/edits/{eid}:commit")
    print(f"committed edit {eid} -> release submitted to '{track}'")


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "verify":
        verify(sys.argv[2])
    elif cmd == "check-upload-key":
        check_upload_key(sys.argv[2], sys.argv[3])
    elif cmd == "publish":
        track = "production"
        if "--track" in sys.argv:
            track = sys.argv[sys.argv.index("--track") + 1]
        publish(sys.argv[2], sys.argv[3], sys.argv[4], track)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
