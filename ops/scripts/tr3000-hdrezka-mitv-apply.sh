#!/bin/sh
# Run ON TR3000 (OpenWrt): deploy boot fixes + HDrezka MiTV poster routing. Idempotent.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
MITV_MAC="${MITV_MAC:-9c:9d:07:d5:e6:54}"
MITV_IP="${MITV_IP:-192.168.2.145}"
LAN_DNS="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"

logger -t tr-hdrezka "apply start"

# --- persist scripts from /tmp if agent deployed there ---
[ -f /tmp/tr3000-wan-recover.sh ] && cp /tmp/tr3000-wan-recover.sh /usr/bin/tr3000-wan-recover && chmod +x /usr/bin/tr3000-wan-recover
[ -f /tmp/tr3000-podkop-restore-mangle.sh ] && cp /tmp/tr3000-podkop-restore-mangle.sh /usr/bin/podkop-restore-mangle.sh && chmod +x /usr/bin/podkop-restore-mangle.sh

if ! grep -q podkop-restore-mangle /usr/bin/podkop-tun-up 2>/dev/null; then
	echo '/usr/bin/podkop-restore-mangle.sh' >> /usr/bin/podkop-tun-up
fi

POSTER_DOMAINS="st.hdrezka.ac static.hdrezka.ac statichdrezka.ac hdrzk.org i.postimg.cc postimg.cc postimg.top image.tmdb.org hdrezka-home.tv"
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

# MiTV DHCP DNS → router
H=""
for sec in $(uci show dhcp 2>/dev/null | sed -n "s/\\(dhcp\\.@host\\[[0-9]*\\]\\)\\.mac=.*/\\1/p"); do
	mac=$(uci -q get "$sec.mac" | tr 'A-Z' 'a-z')
	[ "$mac" = "$MITV_MAC" ] && H=$sec && break
done
if [ -z "$H" ]; then
	H=$(uci add dhcp host)
	uci set "$H.name=Xiaomi-TV-Box"
	uci set "$H.mac=$MITV_MAC"
	uci set "$H.ip=$MITV_IP"
fi
uci -q delete "${H}.dhcp_option" 2>/dev/null || true
uci add_list "${H}.dhcp_option=6,$LAN_DNS"

uci commit podkop
uci commit dhcp

killall -9 uci 2>/dev/null || true

# Soft apply: NEVER /etc/init.d/podkop restart here — it drops Tailscale :2222 for minutes
/etc/init.d/dnsmasq restart
if ! pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop start >/tmp/podkop-mitv-apply.log 2>&1 || true
	sleep 8
else
	# refresh rulesets without full tear-down when possible
	/usr/bin/podkop list_update >/tmp/podkop-list-update.log 2>&1 || true
	sleep 3
fi
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up >/tmp/tun-mitv.log 2>&1 || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
rm -f /tmp/sing-box/cache.db
killall -HUP dnsmasq 2>/dev/null || true
# Keep RunSSH off without restarting tailscaled
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

# Sanity
SB=$(pidof sing-box | wc -l)
MG=$(nft list chain inet PodkopTable mangle 2>/dev/null | grep -c counter || echo 0)
RT=$(ip route get 198.18.0.15 from "$MITV_IP" iif br-lan 2>/dev/null | sed -n '1p')
logger -t tr-hdrezka "apply done sing-box=$SB mangle_rules=$MG route=$RT"
echo "VERIFY sing-box=$SB mangle_rules=$MG"
echo "VERIFY route_fakeip=$RT"
echo "VERIFY voidboost still direct:"
uci get podkop.hdrezka_direct.user_domains 2>/dev/null | tr ' ' '\n' | grep voidboost || true