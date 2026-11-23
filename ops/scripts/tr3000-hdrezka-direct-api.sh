#!/bin/sh
# TR3000 (Cudy): HDRezka API — direct; posters/video CDN — podkop tunnel.
# Не класть hdrezka.ac в exclusion: suffix ломает st.hdrezka.ac (постеры).
# Не применять на WR3000P.

set -e

ROUTER="${ROUTER:-100.81.160.52}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/wr3000p_ed25519}"

apply_local() {
  SECTION=hdrezka_direct

  DIRECT_DOMAINS="
hdrezka.me hdrezka.tv hdrezka.tech hdrezka.app hd-rezka.tv
hdrzk.org rezka.ag rezka.my rezka.fi rezka.land rezka.cc rezka-ua.in rezkify.com
"

  TUNNEL_DOMAINS="
st.hdrezka.ac static.hdrezka.ac statichdrezka.ac hdrezka-fly.net
voidboost.net voidboost.com voidboost.top voidboost.app voidboost.cc
voidcrystal.org static.voidboost.com stream.voidboost.cc stream.voidboost.one
stream.voidboost.in voidslam.org
"

  # suffix would steal posters/CDN into direct
  EXCL_REMOVE="hdrezka.ac hdrezka.ag static.hdrezka.ac statichdrezka.ac st.hdrezka.ac"

  for d in $EXCL_REMOVE; do
    uci -q del_list "podkop.$SECTION.user_domains=$d" 2>/dev/null || true
  done

  for d in $TUNNEL_DOMAINS; do
    if ! uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.main.user_domains=$d"
    fi
  done

  for c in 82.221.0.0/16 82.221.105.13/32; do
    uci -q del_list "podkop.main.user_subnets=$c" 2>/dev/null || true
  done

  for c in 179.43.158.226/32 179.43.154.139/32 82.221.128.101/32 176.58.49.243/32 89.105.207.117/32 176.58.48.71/32 176.58.48.69/32; do
    if ! uci get podkop.main.user_subnets 2>/dev/null | tr " " "\n" | grep -Fx "$c" >/dev/null; then
      uci add_list "podkop.main.user_subnets=$c"
    fi
  done

  if ! uci -q get "podkop.$SECTION" >/dev/null; then
    uci set "podkop.$SECTION=section"
  fi
  uci set "podkop.$SECTION.connection_type=exclusion"
  uci set "podkop.$SECTION.user_domain_list_type=dynamic"

  for d in $DIRECT_DOMAINS; do
    if ! uci get "podkop.$SECTION.user_domains" 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.$SECTION.user_domains=$d"
    fi
  done

  uci commit podkop
  /etc/init.d/podkop restart
  echo "TR3000 hdrezka: API direct, posters/fly via tunnel"
}

if uci get system.@system[0].hostname 2>/dev/null | grep -q '^Cudy$'; then
  apply_local
else
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "root@$ROUTER" "$(declare -f apply_local); apply_local"
fi
