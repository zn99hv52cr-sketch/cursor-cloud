#!/bin/sh
# WR3000P Wi‑Fi: Cursor через podkop (FakeIP), не ломает HDrezka split.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LAN="$(uci get network.lan.ipaddr 2>/dev/null | sed 's|/.*||')"
[ -n "$LAN" ] || LAN=192.168.1.1

CURSOR_DOMAINS="cursor.com cursor.sh api2.cursor.sh api3.cursor.sh cursorapi.com cursor-cdn.com marketplace.cursorapi.com gcpp.cursor.sh auth.cursor.com"

for d in $CURSOR_DOMAINS; do
	uci get podkop.main.user_domains 2>/dev/null | tr " " "\n" | grep -Fx "$d" >/dev/null \
		|| uci add_list podkop.main.user_domains="$d"
	uci get dhcp.@dnsmasq[0].server 2>/dev/null | tr " " "\n" | grep -Fx "/${d}/127.0.0.42" >/dev/null \
		|| uci add_list dhcp.@dnsmasq[0].server="/${d}/127.0.0.42"
done

uci commit podkop
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 2

[ -x /usr/bin/wr3000p-hdrezka-kotikey.sh ] && /usr/bin/wr3000p-hdrezka-kotikey.sh >/dev/null 2>&1
[ -x /usr/bin/wr3000p-hdrezka-video-vpn.sh ] && /usr/bin/wr3000p-hdrezka-video-vpn.sh >/dev/null 2>&1
[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh 2>/dev/null
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up 2>/dev/null
[ -x /usr/bin/wr3000p-podkop-route-fix.sh ] && /usr/bin/wr3000p-podkop-route-fix.sh 2>/dev/null

# main-2-out мёртв для Google/Cursor/voidboost — уводим с неё.
AUTH="Authorization: Bearer diag9090wr"
now=$(wget -qO- --timeout=4 --header="$AUTH" http://127.0.0.1:9090/proxies/main-out 2>/dev/null \
	| grep -o '"now":"[^"]*"' | sed 's/"now":"//;s/"//')
case "$now" in main-2-out|"")
	PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
	[ -n "$PIN" ] && [ "$PIN" != main-2-out ] || PIN=main-4-out
	[ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN"
	;;
esac
[ -x /usr/bin/podkop-tg-pick.sh ] && /usr/bin/podkop-tg-pick.sh 2>/dev/null

echo "cursor dns:"; dig +short @"$LAN" api2.cursor.sh | head -1
echo "voidboost:"; dig +short @"$LAN" voidboost.cc | head -1
echo "hdrzk:"; dig +short @"$LAN" hdrzk.org | head -1
logger -t wr-cursor-wifi "ok pin=$(cat /root/kotikey-pinned-main-out 2>/dev/null)"
exit 0