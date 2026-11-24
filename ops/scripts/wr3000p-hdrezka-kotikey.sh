#!/bin/sh
# MiTV + KotiKey: HDrezka API/плеер — WAN direct; постеры — podkop fakeip/VPN.
# Не трогаем main-out, urltest, KotiKey links. Без podkop restart.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
MITV_IP="${MITV_IP:-192.168.1.164}"
LAN_DNS="$(uci get network.lan.ipaddr 2>/dev/null | sed 's|/.*||' || echo 192.168.1.1)"
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok

ip rule del from "$MITV_IP" table 164 2>/dev/null || true
ip route flush table 164 2>/dev/null || true

# Широкие CDN-подсети в user_subnets гоняют 179.43.x (в т.ч. hdrezka.ag) в VPN — убрать.
for c in 179.43.0.0/16 82.221.0.0/16 195.154.239.0/24 185.231.220.9/32; do
	uci del_list podkop.main.user_subnets="$c" 2>/dev/null || true
done

DIRECT_DNS="hdrezka.ag rezka.ag hdrezka.me hdrzk.org hdrezka-home.tv hdrezka.ac"
uci del_list podkop.main.user_domains=voidcrystal.org 2>/dev/null || true
for d in $DIRECT_DNS; do
	uci del_list podkop.main.user_domains="$d" 2>/dev/null || true
	uci get dhcp.@dnsmasq[0].server 2>/dev/null | grep -q "/${d}/77.88.8.8" \
		|| uci add_list dhcp.@dnsmasq[0].server="/${d}/77.88.8.8"
done

POSTERS="st.hdrezka.ac static.hdrezka.ac statichdrezka.ac i.postimg.cc postimg.cc postimg.top image.tmdb.org"
for d in $POSTERS; do
	uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null \
		|| uci add_list podkop.main.user_domains="$d"
done

uci commit dhcp
uci commit podkop
/etc/init.d/dnsmasq restart
sleep 2

# Podkop 2.x: split на dnsmasq + user_domains; legacy domain_suffix в route.rules не трогаем.

# nft podkop_subnets: обновить без restart podkop (только user subnets)
[ -x /usr/bin/podkop ] && timeout 25 /usr/bin/podkop list_update >/tmp/hk-lu.log 2>&1 || true
/usr/bin/podkop-tun-up 2>/dev/null || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
[ -x /usr/bin/tv-yt-policy ] && /usr/bin/tv-yt-policy 2>/dev/null || true

echo "VERIFY hdrzk.org DNS (не 198.20):"
nslookup hdrzk.org "$LAN_DNS" 2>/dev/null | tail -2
echo "VERIFY hdrezka.ag:"
nslookup hdrezka.ag "$LAN_DNS" 2>/dev/null | tail -2
echo "VERIFY forbidden yt:"
curl -4 -m10 -s -o /dev/null -w "yt=%{http_code}\n" https://www.youtube.com/generate_204