#!/bin/sh
# TR3000: sing-box up but 127.0.0.42 DNS silent — run on router.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

logger -t tr-dns-fix "start"

# dnsmasq → sing-box
if ! uci show dhcp 2>/dev/null | grep -q '127.0.0.42'; then
	uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
	uci add_list dhcp.@dnsmasq[0].server='127.0.0.42#53'
	uci set dhcp.@dnsmasq[0].noresolv='1'
	uci commit dhcp
fi

killall -9 uci podkop-tun-up 2>/dev/null || true

if pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/sing-box restart
else
	/etc/init.d/podkop stop 2>/dev/null || true
	sleep 2
	/usr/bin/podkop start >/tmp/podkop-dns-fix.log 2>&1 &
	sleep 15
fi

[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh

/etc/init.d/dnsmasq restart
sleep 2

# Test fakeip DNS (instagram in main list)
IG=$(nslookup instagram.com 127.0.0.42 2>/dev/null | grep -E "Address:|Name:" | tail -3)
CH=$(nslookup chatgpt.com 127.0.0.42 2>/dev/null | grep -E "Address:|Name:" | tail -3)

logger -t tr-dns-fix "ig=$IG ch=$CH"
echo "VERIFY instagram.com via 127.0.0.42:"
echo "$IG"
echo "VERIFY chatgpt.com via 127.0.0.42:"
echo "$CH"
echo "VERIFY sing-box=$(pidof sing-box | wc -l)"
ss -lnpt 2>/dev/null | grep -E '127.0.0.42:53|1602' || netstat -lnpt 2>/dev/null | grep 127.0.0.42 || true