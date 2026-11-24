#!/bin/sh
# HDrezka MiTV на KotiKey: API/hdrzk.org — WAN direct; voidboost (видео) — через podkop.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok
API_SUFFIX='hdrezka.ag rezka.ag hdrezka.me hdrzk.org hdrezka-home.tv hdrezka.ac'
VOID_DOMAINS='voidboost.cc voidboost.net voidboost.com stream.voidboost.cc'

for d in $VOID_DOMAINS; do
	uci del_list dhcp.@dnsmasq[0].server="/${d}/77.88.8.8" 2>/dev/null || true
	uci del_list dhcp.@dnsmasq[0].server="/${d}/127.0.0.42#53" 2>/dev/null || true
	uci get dhcp.@dnsmasq[0].server 2>/dev/null | tr " " "\n" | grep -Fx "/${d}/127.0.0.42" >/dev/null \
		|| uci add_list dhcp.@dnsmasq[0].server="/${d}/127.0.0.42"
	uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null \
		|| uci add_list podkop.main.user_domains="$d"
done

uci commit podkop
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 2
timeout 25 /usr/bin/podkop list_update 2>/dev/null || true

echo "API hdrzk.org:"; nslookup hdrzk.org 192.168.1.1 2>/dev/null | tail -2
echo "Video voidboost.cc:"; nslookup voidboost.cc 192.168.1.1 2>/dev/null | tail -2
curl -4 -m8 -s -o /dev/null -w "yt=%{http_code}\n" https://www.youtube.com/generate_204