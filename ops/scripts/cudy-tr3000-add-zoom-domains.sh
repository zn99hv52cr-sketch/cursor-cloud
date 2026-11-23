#!/usr/bin/env bash
# Add Zoom domains to podkop.user_domains on Cudy TR3000 only (not WR3000P).
# Prefer LuCI/ubus when OPENWRT_PASSWORD is set; else tailscale ssh.
set -euo pipefail

DOMAINS=(
  zoom.us
  zoom.com
  zoomgov.com
  zoomcdn.com
  zoomcrc.com
)

NAME=cudy-tr3000
IP=100.81.160.52

apply_ubus() {
  CHAT_DOMAINS="${DOMAINS[*]}" OPENWRT_PASSWORD="$OPENWRT_PASSWORD" \
  python3 - "$IP" "$NAME" <<'PY'
import json, os, sys, time, urllib.request

ip, name = sys.argv[1], sys.argv[2]
password = os.environ["OPENWRT_PASSWORD"]
domains = os.environ["CHAT_DOMAINS"].split()

def ubus(sid, obj, method, params=None):
    body = {"jsonrpc": "2.0", "id": 1, "method": "call",
            "params": [sid, obj, method, params or {}]}
    req = urllib.request.Request(
        f"http://{ip}/ubus", data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())

login = ubus("0" * 32, "session", "login", {"username": "root", "password": password})
if login.get("result", [1])[0] != 0:
    raise SystemExit(f"{name}: ubus login failed: {login}")
sid = login["result"][1]["ubus_rpc_session"]
g = ubus(sid, "uci", "get", {"config": "podkop", "section": "main"})
existing = g["result"][1]["values"].get("user_domains") or []
if isinstance(existing, str):
    existing = [existing]
merged = list(existing)
added = []
for d in domains:
    if d not in merged:
        merged.append(d)
        added.append(d)
        print(f"add {d}")
    else:
        print(f"have {d}")
if added:
    ubus(sid, "uci", "set", {
        "config": "podkop", "section": "main",
        "values": {"user_domains": merged},
    })
    ubus(sid, "uci", "commit", {"config": "podkop"})
    ubus(sid, "rc", "init", {"name": "podkop", "action": "restart"})
    time.sleep(3)
    ubus(sid, "rc", "init", {"name": "sing-box", "action": "restart"})
    print("restarted")
else:
    print("no_change")
g2 = ubus(sid, "uci", "get", {"config": "podkop", "section": "main"})
ud = g2["result"][1]["values"].get("user_domains") or []
if isinstance(ud, str):
    ud = [ud]
print("--- zoom-related ---")
for d in ud:
    if "zoom" in d.lower():
        print(d)
print("--- nslookup ---")
time.sleep(1)
for d in ("zoom.us", "zoom.com"):
    ex = ubus(sid, "file", "exec", {
        "command": "/usr/bin/nslookup", "params": [d, "127.0.0.1"],
    })
    stdout = ""
    if ex.get("result") and len(ex["result"]) > 1 and isinstance(ex["result"][1], dict):
        stdout = ex["result"][1].get("stdout") or ""
    addrs = [
        ln.split(":", 1)[1].strip()
        for ln in stdout.splitlines() if ln.startswith("Address:")
    ]
    print(f"{d} -> {addrs[-1] if addrs else '?'}")
PY
}

apply_ssh() {
  local domain_list="${DOMAINS[*]}"
  local remote_script
  remote_script=$(cat <<'REMOTE'
set -euo pipefail
changed=0
for d in __DOMAIN_LIST__; do
  if uci -q get podkop.main.user_domains 2>/dev/null | tr ' ' '\n' | grep -Fxq "$d"; then
    echo "have $d"
  else
    uci add_list podkop.main.user_domains="$d"
    echo "add $d"
    changed=1
  fi
done
if [ "$changed" = 1 ]; then
  uci commit podkop
  /etc/init.d/podkop restart || true
  sleep 3
  /etc/init.d/sing-box restart 2>/dev/null || killall -HUP sing-box 2>/dev/null || true
  echo restarted
else
  echo no_change
fi
echo "--- zoom-related ---"
uci -q get podkop.main.user_domains | tr ' ' '\n' | grep -i zoom || true
echo "--- nslookup ---"
for d in zoom.us zoom.com; do
  addr=$(nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: /{a=$2} END{print a}')
  echo "$d -> ${addr:-?}"
done
REMOTE
)
  local script=${remote_script/__DOMAIN_LIST__/$domain_list}
  # shellcheck disable=SC2029
  tailscale ssh "root@$NAME" "$script"
}

echo "======== $NAME (Zoom only; WR3000P skipped) ========"
if [ -n "${OPENWRT_PASSWORD:-}" ]; then
  if apply_ubus; then
    exit 0
  fi
  echo "$NAME: ubus failed, trying tailscale ssh..."
fi
apply_ssh
