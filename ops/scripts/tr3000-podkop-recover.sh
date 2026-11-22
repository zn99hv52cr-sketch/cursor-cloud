#!/bin/sh
# TR3000: podkop/sing-box down or no resolve for VPN domains — run on router (LAN SSH).
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

logger -t tr-recover "start"

killall -9 uci 2>/dev/null || true
killall -9 podkop-tun-up 2>/dev/null || true

# DNS via sing-box
if ! pidof sing-box >/dev/null 2>&1; then
	logger -t tr-recover "sing-box dead -> podkop start"
	/usr/bin/podkop start >/tmp/podkop-recover.log 2>&1 || /etc/init.d/podkop restart
else
	logger -t tr-recover "sing-box up -> skip full reload; tun+mangle"
fi

sleep 3
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up >/tmp/tun-recover.log 2>&1 || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh || true
[ -x /usr/bin/tr3000-wan-recover ] && /usr/bin/tr3000-wan-recover manual || true

/etc/init.d/dnsmasq restart
killall -HUP dnsmasq 2>/dev/null || true
sleep 2

# Restart sing-box if still broken
if ! nslookup instagram.com 127.0.0.42 >/dev/null 2>&1; then
	logger -t tr-recover "dns-in broken -> podkop restart"
	/etc/init.d/podkop restart
	sleep 12
	[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh || true
	/etc/init.d/dnsmasq restart
fi

SB=$(pidof sing-box | wc -l)
FD=$(nslookup instagram.com 127.0.0.42 2>/dev/null | tail -1)
MG=$(nft list chain inet PodkopTable mangle 2>/dev/null | grep -c counter || echo 0)

logger -t tr-recover "done sb=$SB mangle=$MG dns=$FD"
echo "VERIFY sing-box=$SB mangle_rules=$MG"
echo "VERIFY nslookup instagram.com 127.0.0.42 -> $FD"
echo "VERIFY ping test: curl -m5 -sI https://instagram.com | head -1"