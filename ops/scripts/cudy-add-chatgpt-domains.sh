#!/usr/bin/env bash
# Add ChatGPT/OpenAI domains to podkop.user_domains on both Cudy routers.
# Prefer LuCI/ubus over Tailscale IP when OPENWRT_PASSWORD is set; else tailscale ssh.
set -euo pipefail

DOMAINS=(
  chatgpt.com
  openai.com
  chat.openai.com
  api.openai.com
  auth.openai.com
  platform.openai.com
  oaistatic.com
  oaiusercontent.com
  ab.chatgpt.com
  ws.chatgpt.com
  sora.com
  sora.chatgpt.com
  images.openai.com
  cdn.openai.com
)

# name:ip — Tailscale IPs only (MagicDNS off on routers for podkop DNS)
HOSTS=(
  "cudy-tr3000:100.81.160.52"
  "cudy-wr3000p:100.104.207.62"
)

apply_ubus() {
  local name=$1 ip=$2
  CHAT_DOMAINS="${DOMAINS[*]}" OPENWRT_PASSWORD="$OPENWRT_PASSWORD" \
  python3 - "$ip" "$name" <<'PY'
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
print("--- chatgpt-related ---")
for d in ud:
    if any(x in d for x in ("openai", "chatgpt", "oai", "sora")):
        print(d)
print("--- nslookup ---")
time.sleep(1)
for d in ("chatgpt.com", "openai.com"):
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
  local name=$1
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
echo "--- chatgpt-related ---"
uci -q get podkop.main.user_domains | tr ' ' '\n' | grep -Ei 'openai|chatgpt|oai|sora' || true
echo "--- nslookup ---"
for d in chatgpt.com openai.com; do
  addr=$(nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: /{a=$2} END{print a}')
  echo "$d -> ${addr:-?}"
done
REMOTE
)
  local script=${remote_script/__DOMAIN_LIST__/$domain_list}
  # shellcheck disable=SC2029
  tailscale ssh "root@$name" "$script"
}

for entry in "${HOSTS[@]}"; do
  name=${entry%%:*}
  ip=${entry##*:}
  echo "======== $name ========"
  if [ -n "${OPENWRT_PASSWORD:-}" ]; then
    if apply_ubus "$name" "$ip"; then
      continue
    fi
    echo "$name: ubus failed, trying tailscale ssh..."
  fi
  apply_ssh "$name"
done
