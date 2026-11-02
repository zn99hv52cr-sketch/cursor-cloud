#!/usr/bin/env bash
# Add ChatGPT/OpenAI domains to podkop.user_domains on both Cudy routers.
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

HOSTS=(cudy-tr3000 cudy-wr3000p)

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

domain_list="${DOMAINS[*]}"
for host in "${HOSTS[@]}"; do
  echo "======== $host ========"
  script=${remote_script/__DOMAIN_LIST__/$domain_list}
  # shellcheck disable=SC2029
  tailscale ssh "root@$host" "$script"
done
