#!/bin/sh
# TR3000: Filmix video CDN (cdnsqu / srv224) через podkop.
set -e

ROUTER="${ROUTER:-100.81.160.52}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/wr3000p_ed25519}"

apply() {
  for d in cdnsqu.com filmix.lat thumbs.filmixapp.cyou filmix.quest; do
    if ! uci get podkop.main.user_domains 2>/dev/null | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.main.user_domains=$d"
    fi
  done
  for c in 65.21.160.158/32 65.21.224.187/32 50.7.240.188/32 67.159.8.102/32; do
    if ! uci get podkop.main.user_subnets 2>/dev/null | grep -Fx "$c" >/dev/null; then
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