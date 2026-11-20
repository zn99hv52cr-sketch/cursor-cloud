#!/bin/sh
# TR3000 (Cudy): HDRezka catalog/API — direct (МГТС). CDN voidboost — через podkop.
# В russia_inside уже есть HDRezka → без exclusion API уходит в FI и даёт 403.
# Не применять на WR3000P.

set -e

ROUTER="${ROUTER:-100.81.160.52}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/wr3000p_ed25519}"

apply_local() {
  SECTION=hdrezka_direct
  DIRECT_DOMAINS="
hdrezka.ag hdrezka.ac hdrezka.me hdrezka.tv hdrezka.tech hdrezka.app hd-rezka.tv
hdrzk.org rezka.ag rezka.my rezka.fi rezka.land rezka.cc rezka-ua.in rezkify.com
static.hdrezka.ac statichdrezka.ac st.hdrezka.ac
"

  REMOVE_FROM_MAIN="
hdrezka.ag hdrezka.ac hdrezka.me hdrezka.tv hdrezka.tech hdrezka.app hd-rezka.tv
hdrzk.org rezka.ag rezka.my rezka.fi rezka.land rezka.cc rezka-ua.in rezkify.com
static.hdrezka.ac statichdrezka.ac st.hdrezka.ac voidboost.cc
"

  for d in $REMOVE_FROM_MAIN; do
    while uci -q get "podkop.main.user_domains" 2>/dev/null | grep -Fx "$d" >/dev/null; do
      uci del_list "podkop.main.user_domains=$d"
    done
  done

  for d in voidboost.net voidboost.com voidboost.top voidboost.app voidcrystal.org; do
    if ! uci get podkop.main.user_domains 2>/dev/null | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.main.user_domains=$d"
    fi
  done

  for c in 179.43.189.163/32 179.43.163.206/32 185.231.220.9/32 82.221.0.0/16 82.221.105.13/32; do
    while uci -q get podkop.main.user_subnets 2>/dev/null | grep -Fx "$c" >/dev/null; do
      uci del_list "podkop.main.user_subnets=$c"
    done
  done

  for c in 82.221.128.101/32 176.58.49.243/32; do
    if ! uci get podkop.main.user_subnets 2>/dev/null | grep -Fx "$c" >/dev/null; then
      uci add_list "podkop.main.user_subnets=$c"
    fi
  done

  if ! uci -q get "podkop.$SECTION" >/dev/null; then
    uci set "podkop.$SECTION=section"
  fi
  uci set "podkop.$SECTION.connection_type=exclusion"
  uci set "podkop.$SECTION.user_domain_list_type=dynamic"

  for d in $DIRECT_DOMAINS; do
    if ! uci get "podkop.$SECTION.user_domains" 2>/dev/null | grep -Fx "$d" >/dev/null; then
      uci add_list "podkop.$SECTION.user_domains=$d"
    fi
  done

  uci commit podkop
  /etc/init.d/podkop restart
  echo "TR3000 hdrezka: exclusion + voidboost subnets ok"
}

if [ "$(hostname 2>/dev/null)" = "Cudy" ] || [ -f /etc/openwrt_release ] && uci get system.@system[0].hostname 2>/dev/null | grep -q Cudy; then
  apply_local
else
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "root@$ROUTER" "$(declare -f apply_local); apply_local"
fi