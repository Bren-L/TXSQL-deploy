#!/usr/bin/env python3
"""Create GitHub release and upload tarballs via REST API."""
import urllib.request, urllib.error, json, os, sys

TOKEN = sys.argv[1] if len(sys.argv) > 1 else None
if not TOKEN:
    print("Usage: python create_release.py <github_token>")
    sys.exit(1)

REPO = "Bren-L/TXSQL-deploy"
TAG = "v8.0.30-2.0.0"
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(BASE, "dist")

FILES = [
    "txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz",
    "txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz",
]

BODY = """## v8.0.30-2.0.0 (2026-07-30)

### New
- openEuler 22.03 LTS-SP3 x86_64 support
- Unified install.sh (RPM + binary dual-mode)
- uninstall.sh with --purge support
- systemd/txsql.service + config/my.cnf.template
- Python SSH test harness

### Fixed
- Socket path unified to /run/txsql/mysql.sock
- openEuler user changed from mysql:mysql to txsql:txsql
- openEuler install path changed to /usr/lib/txsql/current
- CentOS 7 systemd 219 compatibility
- RPM config datadir overwrite bug
- Binary mode SELinux context + file ownership
- Password changed from hardcoded to random

### Tested
- CentOS 7.9: 26/26 tests passed
- openEuler 22.03: all tests passed

### Quick Start

**CentOS 7.9:**
```
curl -fSL --retry 3 -# -o txsql.tar.gz \\
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz \\
  && tar xzf txsql.tar.gz && rm -f txsql.tar.gz \\
  && cd txsql-offline-8.0.30-2.0.0-centos7.9-x86_64 \\
  && sudo bash install.sh </dev/null
```

**openEuler 22.03:**
```
curl -fSL --retry 3 -# -o txsql.tar.gz \\
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz \\
  && tar xzf txsql.tar.gz && rm -f txsql.tar.gz \\
  && cd txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64 \\
  && sudo bash install.sh </dev/null
```
"""

def api_json(method, url, data=None):
    """Call GitHub API, return JSON."""
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.read().decode()[:300]}")
        return None
    except Exception as e:
        print(f"  ERR: {e}")
        return None

def upload_asset(upload_url, fname, fpath):
    """Upload a binary file to GitHub release."""
    url = f"{upload_url}?name={fname}"
    with open(fpath, "rb") as fh:
        data = fh.read()
    size_mb = len(data) / (1024 * 1024)
    print(f"  Size: {size_mb:.0f} MB, uploading...", flush=True)

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/gzip")
    req.add_header("Content-Length", str(len(data)))

    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            result = json.loads(resp.read().decode())
            print(f"  OK: {result.get('browser_download_url', '?')}")
            return True
    except urllib.error.HTTPError as e:
        print(f"  HTTP {e.code}: {e.read().decode()[:300]}")
        return False
    except Exception as e:
        print(f"  ERR: {e}")
        return False

def main():
    print(f"=== GitHub Release: {TAG} ===\n")

    # Step 1: Create release
    print("[1/3] Creating release...")
    release = api_json("POST", f"https://api.github.com/repos/{REPO}/releases", {
        "tag_name": TAG,
        "target_commitish": "main",
        "name": f"{TAG} - CentOS 7.9 + openEuler 22.03",
        "body": BODY,
        "draft": False,
        "prerelease": False,
    })

    if not release:
        print("  Checking if release already exists...")
        # GET /repos/{owner}/{repo}/releases/tags/{tag}
        release = api_json("GET", f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}")
    if not release:
        print("  FAILED. Aborting.")
        sys.exit(1)

    upload_url = release["upload_url"].split("{?")[0]
    print(f"  Release ID: {release['id']}")

    # Step 2: Upload assets
    for i, fname in enumerate(FILES):
        fpath = os.path.join(DIST, fname)
        if not os.path.exists(fpath):
            print(f"[2.{i+1}] {fname} - NOT FOUND, skipping")
            continue
        print(f"[2.{i+1}] {fname}", flush=True)
        upload_asset(upload_url, fname, fpath)

    print(f"\n[3/3] Done! https://github.com/{REPO}/releases/tag/{TAG}")

if __name__ == "__main__":
    os.chdir(BASE)
    main()
