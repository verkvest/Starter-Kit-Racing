#!/usr/bin/env python3
"""Register the iOS bundle id in App Store Connect if it is missing.

Reads the API key from disk. Never prints the key or the bearer token.
Does not create the App Store Connect app record (the API cannot).
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

BUNDLE = os.environ.get("BUNDLE_ID", "es.verkvest.veldash")
APP_NAME = os.environ.get("APP_NAME", "Veldash")
KEY_ID = os.environ["APPSTORE_API_KEY_ID"]
ISSUER = os.environ["APPSTORE_API_ISSUER_ID"]
KEY_PATH = os.environ["APPSTORE_API_KEY_PATH"]


def token() -> str:
    with open(KEY_PATH, "r", encoding="utf-8") as handle:
        private_key = handle.read()
    now = int(time.time())
    encoded = jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )
    if isinstance(encoded, bytes):
        return encoded.decode("ascii")
    return encoded


def request(method: str, url: str, bearer: str, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {bearer}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = {"raw": raw[:600]}
        return exc.code, parsed


def create(bearer: str, name: str):
    body = {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": BUNDLE,
                "name": name,
                "platform": "IOS",
            },
        }
    }
    return request("POST", "https://api.appstoreconnect.apple.com/v1/bundleIds", bearer, body)


def main() -> int:
    bearer = token()
    query = urllib.parse.urlencode({"filter[identifier]": BUNDLE})
    status, payload = request(
        "GET",
        f"https://api.appstoreconnect.apple.com/v1/bundleIds?{query}",
        bearer,
    )
    if status != 200:
        print(f"bundle id lookup failed: HTTP {status}")
        print(json.dumps(payload)[:800])
        return 1
    if payload.get("data"):
        print(f"bundle id {BUNDLE} already registered")
        return 0
    status, payload = create(bearer, APP_NAME)
    if status in (201, 409):
        print(f"bundle id {BUNDLE} ready (HTTP {status})")
        return 0
    text = json.dumps(payload)
    if status == 409 or "name" in text.lower():
        status, payload = create(bearer, APP_NAME + " iOS")
        if status in (201, 409):
            print(f"bundle id {BUNDLE} ready under an alternate name (HTTP {status})")
            return 0
    print(f"failed to register bundle id {BUNDLE}: HTTP {status}")
    print(json.dumps(payload)[:800])
    return 1


if __name__ == "__main__":
    sys.exit(main())
