#!/bin/sh
# WR3000P MiTV — по Sharp-бэкапу 2026-11-12: tv-yt-policy (DNS 192.168.1.1, блок QUIC/DoH).
# С KotiKey: hdrezka.ag/rezka/voidboost → direct WAN (как russia_inside), постеры — VPN.
# Table 164 (весь трафик в sbtun) оставлена только под Sharp FI; с KotiKey её НЕ включаем.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
MITV_IP="${MITV_IP:-192.168.1.164}"
MITV_MAC="${MITV_MAC:-c0:09:25:2d:4d:00}"
LAN_DNS="$(uci get network.lan.ipaddr 2>/dev/null | sed 's|/.*||' || echo 192.168.1.1)"
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok

logger -t wr-hdrezka "apply (sharp-tv + kotikey-direct)"

ip rule del from "$MITV_IP" table 164 2>/dev/null || true
ip route flush table 164 2>/dev/null || true

POSTER_DOMAINS="st.hdrezka.ac static.hdrezka.ac statichdrezka.ac hdrzk.org i.postimg.cc postimg.cc postimg.top image.tmdb.org hdrezka-home.tv"
DIRECT_SUFFIX="hdrezka.ag rezka.ag hdrezka.me voidboost.cc voidboost.net voidboost.com stream.voidboost.cc"

for d in voidboost.cc voidboost.net voidboost.com hdrezka.ag rezka.ag hdrezka.me; do
	while uci del_list podkop.main.user_domains="$d" 2>/dev/null; do :; done
done
for d in $POSTER_DOMAINS; do
	uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null \
		|| uci add_list podkop.main.user_domains="$d"
done
for c in 179.43.0.0/16 195.154.239.0/24 82.221.0.0/16 185.231.220.9/32; do
	uci get podkop.main.user_subnets 2>/dev/null | tr " " "\n" | grep -Fx "$c" >/dev/null \
		|| uci add_list podkop.main.user_subnets="$c"
done

# Real DNS для API/плеера (OpenWrt uci — надежнее чем только /etc/dnsmasq.d без conf-dir)
for d in hdrezka.ag rezka.ag hdrezka.me voidboost.cc voidboost.net voidboost.com; do
	uci get dhcp.@dnsmasq[0].server 2>/dev/null | grep -q "/${d}/77.88.8.8" \
		|| uci add_list dhcp.@dnsmasq[0].server="/${d}/77.88.8.8"
done

H=""
for sec in $(uci show dhcp 2>/dev/null | sed -n 's/\(dhcp\.@host\[[0-9]*\]\)\.mac=.*/\1/p'); do
	mac=$(uci -q get "$sec.mac" | tr 'A-Z' 'a-z')
	[ "$mac" = "$(echo "$MITV_MAC" | tr 'A-Z' 'a-z')" ] && H=$sec && break
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
/etc/init.d/dnsmasq restart
sleep 2

if [ -s "$CFG" ] && command -v jq >/dev/null 2>&1; then
	jq '
	  .route.rules |= (
	    [{"domain_suffix":["hdrezka.ag","rezka.ag","hdrezka.me","voidboost.cc","voidboost.net","voidboost.com"],"outbound":"direct-out"}]
	    + (. // [])
	  )
	' "$CFG" > /tmp/sb-hdrezka.json 2>/dev/null && \
		sing-box check -c /tmp/sb-hdrezka.json 2>/dev/null && \
		cp /tmp/sb-hdrezka.json "$CFG" && cp "$CFG" "$OK" && \
		killall -HUP sing-box 2>/dev/null || true
fi

[ -x /usr/bin/tv-yt-policy ] && /usr/bin/tv-yt-policy
/usr/bin/podkop-tun-up 2>/dev/null || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
/usr/bin/wr3000p-podkop-route-fix.sh 2>/dev/null || true
[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh 2>/dev/null || true

killall -HUP dnsmasq 2>/dev/null || true
logger -t wr-hdrezka "apply done"

echo "DNS hdrezka.ag (ожидаем НЕ 198.20.x):"
nslookup hdrezka.ag "$LAN_DNS" 2>/dev/null | tail -2
R=$(nslookup hdrezka.ag "$LAN_DNS" 2>/dev/null | awk '/^Address:/{print $2}' | tail -1)
[ -n "$R" ] && echo "route from MiTV:" && ip route get "$R" from "$MITV_IP" iif br-lan 2>/dev/null | sed -n '1p'