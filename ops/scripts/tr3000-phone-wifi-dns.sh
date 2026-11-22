#!/bin/sh
# Phone on WiFi: force DNS via router (podkop), block DoH/DoT bypass from LAN.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LAN="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"
LAN_NET="$(uci get network.lan.ipaddr 2>/dev/null | sed 's/\.[0-9]*$/.0/')/24"

logger -t tr-phone-wifi "start lan=$LAN"

# dnsmasq -> sing-box only
uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server="127.0.0.42#53"
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localservice='1'
# Push router DNS to all DHCP clients (phones too)
uci -q delete dhcp.lan.dhcp_option 2>/dev/null || true
uci add_list dhcp.lan.dhcp_option="6,$LAN"
uci commit dhcp
/etc/init.d/dnsmasq restart

# Redirect all LAN DNS to router (catch 8.8.8.8 / private DNS attempts)
if ! uci show firewall 2>/dev/null | grep -q 'LAN-DNS-REDIRECT'; then
	uci add firewall redirect
	uci set firewall.@redirect[-1].name='LAN-DNS-REDIRECT'
	uci set firewall.@redirect[-1].src='lan'
	uci set firewall.@redirect[-1].src_dport='53'
	uci set firewall.@redirect[-1].proto='tcp udp'
	uci set firewall.@redirect[-1].target='DNAT'
	uci set firewall.@redirect[-1].dest_ip="$LAN"
	uci set firewall.@redirect[-1].dest_port='53'
	uci set firewall.@redirect[-1].reflection='0'
	uci commit firewall
	/etc/init.d/firewall reload
fi

[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh
killall -HUP dnsmasq 2>/dev/null || true

echo "=== VERIFY phone WiFi ==="
echo "router_dns=$LAN dhcp_option6 ok"
echo "test from router:"
nslookup instagram.com "$LAN" 2>/dev/null | grep Address | tail -2
nslookup instagram.com 127.0.0.42 2>/dev/null | grep Address | tail -2
echo "On PHONE (WiFi): disable Private DNS / set DNS manual $LAN"
echo "Then WiFi forget+reconnect"
logger -t tr-phone-wifi "done"