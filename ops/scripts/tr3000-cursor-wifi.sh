#!/bin/sh
# TR3000: Cursor via podkop even when iOS bypasses router DNS.
set -e
ROUTER="${ROUTER:-100.81.160.52}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/wr3000p_ed25519}"

apply() {
  for d in accounts.spacex.ai accounts.x.ai workos.com download.todesktop.com downloads.cursor.com agent-stores.s3.us-east-1.amazonaws.com agent-stores.s3.amazonaws.com; do
    if ! uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.main.user_domains=$d"
    fi
  done
  # Do NOT add 104.16.0.0/12 or 172.64.0.0/13 — floods podkop and breaks YouTube.
  for c in 104.18.18.125/32 104.18.19.125/32 104.18.16.128/32 104.18.17.128/32 104.18.27.231/32 104.18.26.231/32 104.18.19.80/32 104.18.18.80/32 76.76.0.0/16 66.33.60.0/23 44.213.28.243/32 98.87.193.55/32 34.200.87.105/32; do
    if ! uci get podkop.main.user_subnets 2>/dev/null | tr " " "\n" | grep -Fx "$c" >/dev/null; then
      uci add_list "podkop.main.user_subnets=$c"
    fi
  done
  uci commit podkop
  /etc/init.d/podkop restart
  echo OK
}

if uci get system.@system[0].hostname 2>/dev/null | grep -q '^Cudy$'; then
  apply
else
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "root@$ROUTER" "$(declare -f apply); apply"
fi
