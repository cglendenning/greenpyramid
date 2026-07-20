#!/usr/bin/env python3
"""App Store Connect release helper for Green Pyramid.

Subcommands (all read config from the constants below):
  builds                      List recent builds and their processing state.
  create-version X.Y.Z        Create (or fetch existing) App Store version.
  attach-build X.Y.Z BUILD    Attach a processed build (by CFBundleVersion) to a version.
  set-notes X.Y.Z FILE        Set the What's New text for a version from FILE.
  version-info X.Y.Z          Show version id, state, and attached build.
  screenshot-sets X.Y.Z       List screenshot sets (display types) on a version.
  upload-screenshots X.Y.Z DISPLAY_TYPE PNG [PNG ...]
                              Replace the screenshot set of DISPLAY_TYPE with PNGs.

Auth: App Store Connect API key (.p8 in ~/.appstoreconnect/private_keys).
"""
import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path
from typing import List, Optional

import jwt

KEY_ID = "MRKVCR3WF6"
ISSUER_ID = "78bfbe39-6c61-4296-b086-b36925bcc396"
APP_ID = "6450578276"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
BASE = "https://api.appstoreconnect.apple.com"


def token() -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(),
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )


def api(method: str, path: str, body: Optional[dict] = None,
        content_type: str = "application/json", raw: Optional[bytes] = None) -> dict:
    req = urllib.request.Request(BASE + path if path.startswith("/") else path,
                                 method=method)
    req.add_header("Authorization", f"Bearer {token()}")
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
        detail = e.read().decode()
        raise SystemExit(f"HTTP {e.code} on {method} {path}:\n{detail}")


def list_builds(limit: int = 10) -> None:
    data = api("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate"
                      f"&limit={limit}&fields[builds]=version,processingState,uploadedDate")
    for b in data["data"]:
        a = b["attributes"]
        print(f"build {a['version']:>6}  {a['processingState']:<12} "
              f"uploaded {a['uploadedDate']}  id={b['id']}")


def pre_release_version_of_build(build_id: str) -> str:
    data = api("GET", f"/v1/builds/{build_id}/preReleaseVersion")
    return data["data"]["attributes"]["version"] if data.get("data") else "?"


def find_version(version: str) -> Optional[dict]:
    data = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions"
                      f"?filter[versionString]={version}&limit=1")
    return data["data"][0] if data["data"] else None


def create_version(version: str) -> None:
    existing = find_version(version)
    if existing:
        print(f"version {version} already exists: id={existing['id']} "
              f"state={existing['attributes']['appStoreState']}")
        return
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": version},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    data = api("POST", "/v1/appStoreVersions", body)
    print(f"created version {version}: id={data['data']['id']}")


def attach_build(version: str, bundle_version: str) -> None:
    v = find_version(version)
    if not v:
        raise SystemExit(f"App Store version {version} not found — create it first")
    builds = api("GET", f"/v1/builds?filter[app]={APP_ID}&filter[version]={bundle_version}"
                        f"&sort=-uploadedDate&limit=5")
    candidates = [b for b in builds["data"]
                  if pre_release_version_of_build(b["id"]) == version]
    if not candidates:
        raise SystemExit(f"no build {bundle_version} with train {version} found")
    build = candidates[0]
    state = build["attributes"]["processingState"]
    if state != "VALID":
        raise SystemExit(f"build {bundle_version} is {state}, not VALID — wait for processing")
    body = {"data": {"type": "builds", "id": build["id"]}}
    api("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", body)
    print(f"attached build {bundle_version} ({build['id']}) to version {version}")


def version_info(version: str) -> None:
    v = find_version(version)
    if not v:
        print(f"version {version}: not found")
        return
    print(f"version {version}: id={v['id']} state={v['attributes']['appStoreState']}")
    b = api("GET", f"/v1/appStoreVersions/{v['id']}/build")
    if b.get("data"):
        print(f"  attached build: {b['data']['attributes']['version']} "
              f"({b['data']['attributes']['processingState']})")
    else:
        print("  attached build: none")


def localization_id(version: str) -> str:
    v = find_version(version)
    if not v:
        raise SystemExit(f"version {version} not found")
    locs = api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
    for loc in locs["data"]:
        if loc["attributes"]["locale"] in ("en-US", "en-GB"):
            return loc["id"]
    raise SystemExit(f"no English localization on version {version}")


def set_notes(version: str, notes_file: str) -> None:
    loc_id = localization_id(version)
    notes = Path(notes_file).read_text().strip()
    body = {"data": {"type": "appStoreVersionLocalizations", "id": loc_id,
                     "attributes": {"whatsNew": notes}}}
    api("PATCH", f"/v1/appStoreVersionLocalizations/{loc_id}", body)
    print(f"set What's New for {version} ({len(notes)} chars)")


def set_privacy_url(url: str) -> None:
    infos = api("GET", f"/v1/apps/{APP_ID}/appInfos")
    for info in infos["data"]:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        locs = api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")
        for loc in locs["data"]:
            if not loc["attributes"]["locale"].startswith("en"):
                continue
            body = {"data": {"type": "appInfoLocalizations", "id": loc["id"],
                             "attributes": {"privacyPolicyUrl": url}}}
            try:
                api("PATCH", f"/v1/appInfoLocalizations/{loc['id']}", body)
                print(f"set privacy URL on appInfo {info['id']} ({state}) "
                      f"{loc['attributes']['locale']}")
            except SystemExit as e:
                # The live appInfo is read-only; only the editable one accepts
                # the change. Report and continue.
                print(f"skipped appInfo {info['id']} ({state}): not editable")


def screenshot_sets(version: str) -> None:
    loc_id = localization_id(version)
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    for s in sets["data"]:
        shots = api("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots"
                           f"?fields[appScreenshots]=fileName,assetDeliveryState")
        print(f"{s['attributes']['screenshotDisplayType']}: id={s['id']} "
              f"{len(shots['data'])} screenshots")
        for shot in shots["data"]:
            print(f"    {shot['attributes']['fileName']} "
                  f"{shot['attributes']['assetDeliveryState']['state']}")


def upload_screenshots(version: str, display_type: str, files: List[str]) -> None:
    loc_id = localization_id(version)
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    set_id = None
    for s in sets["data"]:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            set_id = s["id"]
            break
    if set_id is None:
        body = {"data": {"type": "appScreenshotSets",
                         "attributes": {"screenshotDisplayType": display_type},
                         "relationships": {"appStoreVersionLocalization":
                             {"data": {"type": "appStoreVersionLocalizations",
                                       "id": loc_id}}}}}
        set_id = api("POST", "/v1/appScreenshotSets", body)["data"]["id"]
        print(f"created screenshot set {display_type}: {set_id}")

    # Clear existing shots so the new set fully replaces the old one.
    existing = api("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
    for shot in existing["data"]:
        api("DELETE", f"/v1/appScreenshots/{shot['id']}")
        print(f"deleted old screenshot {shot['id']}")

    for f in files:
        p = Path(f)
        blob = p.read_bytes()
        body = {"data": {"type": "appScreenshots",
                         "attributes": {"fileName": p.name, "fileSize": len(blob)},
                         "relationships": {"appScreenshotSet":
                             {"data": {"type": "appScreenshotSets", "id": set_id}}}}}
        shot = api("POST", "/v1/appScreenshots", body)["data"]
        for op in shot["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
            start, length = op["offset"], op["length"]
            req = urllib.request.Request(op["url"], method=op["method"],
                                         data=blob[start:start + length])
            for k, v in headers.items():
                req.add_header(k, v)
            urllib.request.urlopen(req).read()
        commit = {"data": {"type": "appScreenshots", "id": shot["id"],
                           "attributes": {"uploaded": True,
                                          "sourceFileChecksum":
                                              hashlib.md5(blob).hexdigest()}}}
        api("PATCH", f"/v1/appScreenshots/{shot['id']}", commit)
        print(f"uploaded {p.name}")


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "builds":
        list_builds()
    elif cmd == "create-version":
        create_version(sys.argv[2])
    elif cmd == "attach-build":
        attach_build(sys.argv[2], sys.argv[3])
    elif cmd == "set-notes":
        set_notes(sys.argv[2], sys.argv[3])
    elif cmd == "version-info":
        version_info(sys.argv[2])
    elif cmd == "set-privacy-url":
        set_privacy_url(sys.argv[2])
    elif cmd == "screenshot-sets":
        screenshot_sets(sys.argv[2])
    elif cmd == "upload-screenshots":
        upload_screenshots(sys.argv[2], sys.argv[3], sys.argv[4:])
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
