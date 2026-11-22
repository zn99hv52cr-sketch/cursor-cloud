#!/bin/sh
# iPhone on WiFi: DNS via router + kill IPv6/QUIC/DoT bypass (podkop fakeip + tproxy).
# Safe: no podkop restart, no tailscale restart.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LAN="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"
IPHONE_IP="${IPHONE_IP:-192.168.2.195}"
logger -t tr-ios-wifi "start lan=$LAN iphone=$IPHONE_IP"

# --- DNS (same as phone-wifi-dns) ---
uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server="127.0.0.42#53"
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localservice='1'
uci -q delete dhcp.lan.dhcp_option 2>/dev/null || true
uci add_list dhcp.lan.dhcp_option="6,$LAN"
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci commit dhcp

uci set network.lan.ipv6='0' 2>/dev/null || true
uci commit network 2>/dev/null || true

if [ -f /etc/config/odhcpd ]; then
	uci set odhcpd.odhcpd.leasefile='/tmp/hosts/odhcpd' 2>/dev/null || true
	uci set odhcpd.odhcpd.maindhcp='0' 2>/dev/null || true
	uci commit odhcpd 2>/dev/null || true
fi

cat > /etc/sysctl.d/99-ios-wifi.conf << 'SYS'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.br-lan.disable_ipv6=1
net.ipv6.conf.eth0.disable_ipv6=1
SYS
sysctl -p /etc/sysctl.d/99-ios-wifi.conf 2>/dev/null || true

/etc/init.d/dnsmasq restart
sleep 2

ensure_fw_rule() {
	name="$1"
	shift
	sec="$(uci show firewall 2>/dev/null | sed -n "s/^\(firewall\.[^=]*\)\.name='${name}'/\1/p" | head -1)"
	if [ -z "$sec" ]; then
		uci add firewall rule
		sec="firewall.@rule[-1]"
		uci set "${sec}.name=${name}"
	fi
	while [ $# -ge 2 ]; do
		uci set "${sec}.$1=$2"
		shift 2
	done
}

if ! uci show firewall 2>/dev/null | grep -q 'LAN-DNS-REDIRECT'; then
	uci add firewall redirect
	uci set firewall.@redirect[-1].name='LAN-DNS-REDIRECT'
	uci set firewall.@redirect[-1].src='lan'
	uci set firewall.@redirect[-1].dest='lan'
	uci set firewall.@redirect[-1].src_dport='53'
	uci set firewall.@redirect[-1].proto='tcp udp'
	uci set firewall.@redirect[-1].target='DNAT'
	uci set firewall.@redirect[-1].dest_ip="$LAN"
	uci set firewall.@redirect[-1].dest_port='53'
	uci set firewall.@redirect[-1].reflection='0'
else
	idx="$(uci show firewall 2>/dev/null | sed -n 's/^\(firewall\.[^=]*\)=redirect.*LAN-DNS-REDIRECT.*/\1/p' | head -1)"
	[ -n "$idx" ] && uci set "${idx}.dest=lan" 2>/dev/null || true
fi

ensure_fw_rule 'LAN-Block-QUIC-WAN' \
	src lan dest wan proto udp dest_port 443 target REJECT

ensure_fw_rule 'LAN-Block-DoT-WAN' \
	src lan dest wan proto 'tcp udp' dest_port 853 target REJECT

uci commit firewall
/etc/init.d/firewall reload

for d in instagram.com cdninstagram.com facebook.com fbcdn.net \
	whatsapp.com apple-dns.net; do
	uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null && continue
	uci add_list podkop.main.user_domains="$d" 2>/dev/null || true
done
uci commit podkop 2>/dev/null || true

if pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop list_update >/tmp/podkop-ios-list.log 2>&1 || true
	sleep 2
else
	/usr/bin/podkop start >/tmp/podkop-ios-start.log 2>&1 || true
	sleep 8
fi

[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up >/tmp/tun-ios.log 2>&1 || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh || true
rm -f /tmp/sing-box/cache.db 2>/dev/null || true
killall -HUP dnsmasq 2>/dev/null || true
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

echo "=== iOS WiFi fix VERIFY ==="
echo "sing-box=$(pidof sing-box | wc -l)"
echo "instagram @ router:"
nslookup instagram.com 127.0.0.42 2>/dev/null | grep Address | tail -2
echo "route fakeip from iPhone IP $IPHONE_IP:"
ip route get 198.18.0.26 from "$IPHONE_IP" iif br-lan 2>/dev/null | head -1
nft list chain inet PodkopTable mangle 2>/dev/null | grep counter | head -2
echo ""
echo "iPhone: WiFi forget+reconnect; DNS manual $LAN; VPN profiles OFF (Happ/Outline)."
echo "Settings -> VPN: must be Not Connected."
logger -t tr-ios-wifi "done"