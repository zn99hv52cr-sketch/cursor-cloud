#!/bin/sh
# Run on Cudy while iPhone on WiFi — find why LAN client does not load blocked sites.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LAN="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"

echo "=== iPhone lease (pick your IP) ==="
awk '$1=="lease" {print $2, $NF}' /tmp/dhcp.leases 2>/dev/null | while read -r ip rest; do
	echo "  $ip $rest"
done
echo "router LAN=$LAN"

echo ""
echo "=== dhcp DNS pushed to clients ==="
uci get dhcp.lan.dhcp_option 2>/dev/null || echo "(none)"
uci get dhcp.@dnsmasq[0].server 2>/dev/null || true

echo ""
echo "=== podkop / sing-box ==="
echo "sing-box pids: $(pidof sing-box 2>/dev/null || echo 0)"
nslookup instagram.com 127.0.0.42 2>/dev/null | grep -i address || true
nslookup instagram.com "$LAN" 2>/dev/null | grep -i address || true

echo ""
echo "=== router itself can open instagram? ==="
IG=$(curl -4 -sS -m 15 -o /dev/null -w "%{http_code}" https://www.instagram.com/ 2>/dev/null || echo "curl_fail")
echo "curl https://www.instagram.com from router: HTTP $IG"

if [ -z "${IPHONE_IP:-}" ]; then
	IPHONE_IP="$(awk '$0 ~ /iPhone|iphone|iPad/ {print $3; exit}' /tmp/dhcp.leases 2>/dev/null)"
	[ -z "$IPHONE_IP" ] && IPHONE_IP="$(awk 'END{print $3}' /tmp/dhcp.leases 2>/dev/null)"
fi
echo ""
echo "=== path from LAN client IP=${IPHONE_IP:-unknown} (set IPHONE_IP=... if wrong) ==="
if [ -n "${IPHONE_IP:-}" ]; then
	ip route get 198.18.0.26 from "$IPHONE_IP" iif br-lan 2>/dev/null | head -1
else
	echo "no IPHONE_IP and no lease hint"
fi

echo ""
echo "=== nft mangle (must see counters grow when iPhone loads site) ==="
nft list set inet PodkopTable interfaces 2>/dev/null | head -5
nft list chain inet PodkopTable mangle 2>/dev/null | grep counter | head -4

echo ""
echo "=== iOS bypass checks ==="
echo "ipv6 br-lan: $(cat /proc/sys/net/ipv6/conf/br-lan/disable_ipv6 2>/dev/null || echo ?)"
uci get firewall 2>/dev/null | grep -E "LAN-Block-QUIC|LAN-Block-DoT|LAN-DNS" || true

echo ""
echo "=== WHILE THIS RUNS: on iPhone Safari open instagram.com, then Ctrl+C and run: ==="
echo "logread | tail -30 | grep -i dnsmasq"
echo "nft list chain inet PodkopTable mangle | grep counter"