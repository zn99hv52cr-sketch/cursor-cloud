#!/bin/sh
# TR3000: HDRezka like the ISP router — real DNS, no podkop/VLESS.
set -e
ROUTER="${ROUTER:-100.81.160.52}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/wr3000p_ed25519}"

apply() {
  ALL="hdrezka.ag hdrezka.ac hdrezka.me hdrezka.tv hdrezka.tech hdrezka.app hd-rezka.tv hdrezka-fly.net
hdrzk.org rezka.ag rezka.my rezka.fi rezka.land rezka.cc rezka-ua.in rezkify.com
st.hdrezka.ac static.hdrezka.ac statichdrezka.ac
voidboost.net voidboost.com voidboost.top voidboost.app voidboost.cc
static.voidboost.com stream.voidboost.cc stream.voidboost.one stream.voidboost.in
voidcrystal.org voidslam.org"

  for d in $ALL; do
    uci -q del_list podkop.main.user_domains="$d" || true
  done
  uci set podkop.hdrezka_direct=section
  uci set podkop.hdrezka_direct.connection_type=exclusion
  uci set podkop.hdrezka_direct.user_domain_list_type=dynamic
  for d in $ALL; do
    if ! uci get podkop.hdrezka_direct.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null; then
      uci add_list podkop.hdrezka_direct.user_domains="$d"
    fi
  done
  for c in 82.221.128.101/32 176.58.49.243/32 179.43.158.226/32 179.43.154.139/32 89.105.207.117/32 176.58.48.71/32 176.58.48.69/32; do
    uci -q del_list podkop.main.user_subnets="$c" || true
    ip route del "$c" dev sbtun 2>/dev/null || true
  done
  uci commit podkop

  cat > /etc/dnsmasq.d/hdrezka-direct.conf << "EOF"
server=/hdrzk.org/77.88.8.8
server=/hdrezka.ac/77.88.8.8
server=/hdrezka.ag/77.88.8.8
server=/hdrezka.me/77.88.8.8
server=/hdrezka.tv/77.88.8.8
server=/hdrezka.tech/77.88.8.8
server=/hdrezka.app/77.88.8.8
server=/hd-rezka.tv/77.88.8.8
server=/hdrezka-fly.net/77.88.8.8
server=/rezka.ag/77.88.8.8
server=/rezka.my/77.88.8.8
server=/rezka.fi/77.88.8.8
server=/rezka.land/77.88.8.8
server=/rezka.cc/77.88.8.8
server=/rezka-ua.in/77.88.8.8
server=/rezkify.com/77.88.8.8
server=/voidboost.net/77.88.8.8
server=/voidboost.com/77.88.8.8
server=/voidboost.top/77.88.8.8
server=/voidboost.app/77.88.8.8
server=/voidboost.cc/77.88.8.8
server=/voidcrystal.org/77.88.8.8
server=/voidslam.org/77.88.8.8
EOF
  /etc/init.d/dnsmasq restart
  echo OK
}

if uci get system.@system[0].hostname 2>/dev/null | grep -q '^Cudy$'; then
  apply
else
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "root@$ROUTER" "$(declare -f apply); apply"
fi
