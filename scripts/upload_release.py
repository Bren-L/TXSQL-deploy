#!/usr/bin/env python3
"""Upload corrected tarballs to v8.0.30-2.0.0 release (delete old first)."""
import urllib.request, urllib.error, json, os, sys

TOKEN = sys.argv[1]
REPO = "Bren-L/TXSQL-deploy"
TAG = "v8.0.30-2.0.0"
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(BASE, "dist")

FILES = [
    "txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz",
    "txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz",
]

def api(method, url, data=None, raw=False):
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    if not raw:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode()) if not raw else resp.read()
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  HTTP {e.code}: {err[:200]}")
        return None

# Step 1: Get release
print("=== Upload corrected tarballs ===\n")
release = api("GET", f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}")
if not release:
    print("Release not found!")
    sys.exit(1)
print(f"Release ID: {release['id']}")

# Step 2: Delete old assets
print("\n[1/3] Deleting old assets...")
for asset in release.get("assets", []):
    name = asset["name"]
    if name in FILES:
        print(f"  Deleting {name}...")
        result = api("DELETE", asset["url"], raw=True)
        if result is not None:
            print(f"    Deleted.")

# Step 3: Upload new assets
upload_url = release["upload_url"].split("{?")[0]
print(f"\n[2/3] Uploading new tarballs...")
for fname in FILES:
    fpath = os.path.join(DIST, fname)
    if not os.path.exists(fpath):
        print(f"  {fname} - NOT FOUND!")
        continue
    size_mb = os.path.getsize(fpath) / (1024 * 1024)
    print(f"  {fname} ({size_mb:.0f} MB) ... ", end="", flush=True)

    with open(fpath, "rb") as fh:
        data = fh.read()

    req = urllib.request.Request(f"{upload_url}?name={fname}", data=data, method="POST")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/gzip")
    req.add_header("Content-Length", str(len(data)))
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            result = json.loads(resp.read().decode())
            print("OK")
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}")
    except Exception as e:
        print(f"ERR: {e}")

# Step 4: Update release body
print(f"\n[3/3] Updating release body...")
new_body = release["body"] + "\n\n### Updated 2026-07-31\n- Fixed tarball internal directory name (was 1.0.0, now 2.0.0)\n- Updated README.md inside both packages\n- Fixed openEuler PLATFORM metadata"
api("PATCH", release["url"], {"body": new_body})
print("Done!")

print(f"\n  https://github.com/{REPO}/releases/tag/{TAG}")
