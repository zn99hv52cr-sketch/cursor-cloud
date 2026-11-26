#!/bin/sh
# WR3000P: каждые 5 мин — без перебора нод, только pin + lock + HDrezka DNS sanity.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh 2>/dev/null
[ -x /usr/bin/podkop-tg-pick.sh ] && /usr/bin/podkop-tg-pick.sh 2>/dev/null
PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
[ -n "$PIN" ] && [ "$PIN" != "main-2-out" ] && [ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN" 2>/dev/null
AUTH="Authorization: Bearer diag9090wr"
case "$(wget -qO- --timeout=3 --header="$AUTH" http://127.0.0.1:9090/proxies/main-out 2>/dev/null | grep -o '"now":"[^"]*"' | sed 's/"now":"//;s/"//')" in
	main-2-out|"") [ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "${PIN:-main-4-out}" 2>/dev/null;;
esac

# sbtun пропал после ребута WAN — лёгкий tun-up (без podkop restart).
if ! ip link show sbtun >/dev/null 2>&1 || ! ip route show 198.20.0.0/15 2>/dev/null | grep -q 'dev sbtun'; then
	[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up 2>/dev/null
fi

# hdrzk не должен снова уехать в FakeIP.
H=$(dig +short @192.168.1.1 hdrzk.org 2>/dev/null | head -1)
case "$H" in 198.20.*|198.18.*)
	logger -t wr-antidrift "hdrzk fakeip $H — repair"
	[ -x /usr/bin/wr3000p-hdrezka-kotikey.sh ] && /usr/bin/wr3000p-hdrezka-kotikey.sh >/dev/null 2>&1
	;;
esac
exit 0