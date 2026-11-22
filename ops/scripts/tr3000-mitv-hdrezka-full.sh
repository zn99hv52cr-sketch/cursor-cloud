#!/bin/sh
# TR3000: MiTV HDrezka — posters after search (video via voidboost direct unchanged).
set -e
MITV_MAC="${MITV_MAC:-9c:9d:07:d5:e6:54}"

POSTER_DOMAINS="st.hdrezka.ac static.hdrezka.ac statichdrezka.ac i.postimg.cc postimg.cc postimg.top image.tmdb.org hdrezka-home.tv hdrzk.org"

# 1) Posters → VPN (main), not hdrezka_direct (direct WAN to 179.43.x often dies)
for d in $POSTER_DOMAINS; do
  while uci del_list podkop.hdrezka_direct.user_domains="$d" 2>/dev/null; do :; done
  if ! uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null; then
    uci add_list podkop.main.user_domains="$d"
  fi
done

for c in 179.43.0.0/16 195.154.239.0/24 82.221.0.0/16 185.231.220.9/32; do
  if ! uci get podkop.main.user_subnets 2>/dev/null | tr " " "\n" | grep -Fx "$c" >/dev/null; then
    uci add_list podkop.main.user_subnets="$c"
  fi
done

# 2) MiTV: DHCP pushes DNS 192.168.2.1 (скип Google DoH на приставке)
LAN_DNS="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"
H=""
while read -r line; do
  case "$line" in
    *"$MITV_MAC"*) H=$(echo "$line" | cut -d. -f1-2); break ;;
  esac
done <<EOF
$(uci show dhcp 2>/dev/null | grep "\.mac=")
EOF
if [ -z "$H" ]; then
  uci add dhcp host
  H=$(uci show dhcp | tail -1 | sed 's/=.*//')
  uci set "$H".name='Xiaomi-TV-Box'
  uci set "$H".mac="$MITV_MAC"
  uci set "$H".ip='192.168.2.145'
fi
uci -q delete "$H".dhcp_option 2>/dev/null || true
uci add_list "$H.dhcp_option=6,$LAN_DNS"

uci commit podkop
uci commit dhcp
/etc/init.d/dhcp restart 2>/dev/null || /etc/init.d/dnsmasq restart
/etc/init.d/podkop restart
sleep 10
rm -f /tmp/sing-box/cache.db
killall -HUP dnsmasq 2>/dev/null || true

echo "OK posters=vpn voidboost=direct mitv_mac=$MITV_MAC dns=router"