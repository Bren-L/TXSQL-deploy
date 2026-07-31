#!/usr/bin/env python3
"""Push local git repo to GitHub via REST API. Token from command line."""
import subprocess, json, os, sys, base64, urllib.request, urllib.error

TOKEN = sys.argv[1] if len(sys.argv) > 1 else None
if not TOKEN:
    print("Usage: python git_push_via_api.py <github_token>")
    sys.exit(1)

REPO = "Bren-L/TXSQL-deploy"
BRANCH = "main"

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, shell=True)

def api(method, endpoint, data=None):
    url = f"https://api.github.com/repos/{REPO}/{endpoint}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  API {e.code}: {err[:300]}")
        return None
    except Exception as e:
        print(f"  API ERR: {e}")
        return None

def push():
    print("=== Push TXSQL to GitHub via API ===\n")

    files = sorted([f.strip() for f in run("git ls-files").stdout.strip().split("\n") if f.strip()])
    print(f"[1/5] {len(files)} files")

    ref = api("GET", f"git/ref/heads/{BRANCH}")
    parent = ref.get("object", {}).get("sha") if ref else None
    print(f"[2/5] Remote {BRANCH}: {parent[:8] if parent else 'empty'}")

    print(f"[3/5] Creating blobs...", flush=True)
    blobs = {}
    BINARY = {'.tar.gz', '.bz2', '.gz', '.png', '.jpg', '.zip', '.rpm'}

    for i, f in enumerate(files):
        is_bin = any(f.endswith(e) for e in BINARY)
        try:
            if not is_bin:
                with open(f, "r", encoding="utf-8") as fh:
                    content = fh.read()
                encoding = "utf-8"
            else:
                raise UnicodeDecodeError("", b"", 0, 1, "")
        except:
            with open(f, "rb") as fh:
                content = base64.b64encode(fh.read()).decode("ascii")
            encoding = "base64"

        blob = api("POST", "git/blobs", {"content": content, "encoding": encoding})
        if blob and "sha" in blob:
            mode = "100755" if (f.endswith(".sh") or f.endswith(".py")) else "100644"
            blobs[f] = {"sha": blob["sha"], "mode": mode}

        if (i+1) % 20 == 0: print(f"  {i+1}/{len(files)}", flush=True)

    print(f"  {len(blobs)}/{len(files)} blobs created")

    if not blobs:
        print("ERROR: No blobs!"); return

    # Tree
    print(f"[4/5] Creating tree...")
    tree_items = [{"path": f.replace("\\","/"), "mode": blobs[f]["mode"], "type": "blob", "sha": blobs[f]["sha"]}
                  for f in sorted(blobs)]
    tree = api("POST", "git/trees", {"tree": tree_items})
    if not tree or "sha" not in tree: return print(f"TREE FAIL: {tree}")
    print(f"  Tree: {tree['sha']}")

    # Commit
    msg = run("git log -1 --format=%B").stdout.strip()
    author = {"name": run("git log -1 --format=%an").stdout.strip(),
              "email": run("git log -1 --format=%ae").stdout.strip()}
    commit = api("POST", "git/commits", {"message": msg, "author": author, "tree": tree["sha"],
                                          **({"parents": [parent]} if parent else {})})
    if not commit or "sha" not in commit: return print(f"COMMIT FAIL: {commit}")
    sha = commit["sha"]
    print(f"  Commit: {sha}")

    # Update ref
    print(f"[5/5] Pushing to {BRANCH}...")
    if parent:
        result = api("PATCH", f"git/refs/heads/{BRANCH}", {"sha": sha, "force": True})
    else:
        result = api("POST", "git/refs", {"ref": f"refs/heads/{BRANCH}", "sha": sha})
    if result:
        print(f"\n  ✓ PUSHED!")
        print(f"  https://github.com/{REPO}")
    else:
        print(f"  ✗ FAILED")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    push()
