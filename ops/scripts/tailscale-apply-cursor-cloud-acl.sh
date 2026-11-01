#!/usr/bin/env bash
# One-shot: tag Cudy routers + SSH accept for Cloud Agent (needs TAILSCALE_API_KEY).
set -euo pipefail

export TAILSCALE_API_KEY="${TAILSCALE_API_KEY:?Set TAILSCALE_API_KEY (tskey-api-...)}"
TAILNET="${TAILSCALE_TAILNET:--}"

python3 << 'PY'
import json
import os
import urllib.request
import base64

api = os.environ["TAILSCALE_API_KEY"]
tailnet = os.environ.get("TAILSCALE_TAILNET", "-")
base = f"https://api.tailscale.com/api/v2/tailnet/{tailnet}"

def auth_header():
    token = base64.b64encode(f"{api}:".encode()).decode()
    return {"Authorization": f"Basic {token}"}

def req(method, url, body=None, headers=None):
    h = auth_header()
    if headers:
        h.update(headers)
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(url, data=data, method=method, headers=h)
    with urllib.request.urlopen(r, timeout=60) as resp:
        raw = resp.read()
        etag = resp.headers.get("ETag")
        if raw:
            return etag, json.loads(raw.decode())
        return etag, None

etag, acl = req("GET", f"{base}/acl", headers={"Accept": "application/json"})
tag_owners = acl.setdefault("tagOwners", {})
tag_owners.setdefault("tag:cursor-cloud", ["autogroup:admin"])
tag_owners.setdefault("tag:cudy", ["autogroup:admin"])

ssh = acl.setdefault("ssh", [])
rule = {"action": "accept", "src": ["tag:cursor-cloud"], "dst": ["tag:cudy"], "users": ["root"]}
if not any(isinstance(r, dict) and r.get("src") == rule["src"] and r.get("dst") == rule["dst"] for r in ssh):
    ssh.insert(0, rule)

acls = acl.setdefault("acls", [])
port_rule = {"action": "accept", "src": ["tag:cursor-cloud"], "dst": ["tag:cudy:22"]}
if not any(isinstance(r, dict) and r.get("src") == port_rule["src"] and r.get("dst") == port_rule["dst"] for r in acls):
    acls.append(port_rule)

headers = {"Content-Type": "application/json", "Accept": "application/json"}
if etag:
    headers["If-Match"] = etag
req("POST", f"{base}/acl", acl, headers=headers)
print("ACL updated (tag:cursor-cloud -> tag:cudy SSH accept)")

_, devices_payload = req("GET", f"https://api.tailscale.com/api/v2/tailnet/{tailnet}/devices")
for d in devices_payload.get("devices", []):
    name = (d.get("name") or "").split(".")[0]
    if name not in ("cudy-tr3000", "cudy-wr3000p"):
        continue
    did = d["id"]
    tags = sorted(set((d.get("tags") or []) + ["tag:cudy"]))
    req(
        "POST",
        f"https://api.tailscale.com/api/v2/device/{did}/tags",
        {"tags": tags},
        headers={"Content-Type": "application/json"},
    )
    print(f"Tagged {name} -> {tags}")
print("Done")
PY
