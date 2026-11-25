#!/bin/sh
# WR3000P: поднять KotiKey + HDrezka после ребута (без tailscale restart, без podkop restart если sing-box жив).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
PIN="${KOTIKEY_PIN:-$(cat /root/kotikey-pinned-main-out 2>/dev/null)}"
[ -n "$PIN" ] || PIN=main-1-out
LOG=/tmp/wr-boot-stable.log
API_LOCAL="http://127.0.0.1:9090/proxies/main-out"
API_LAN="http://192.168.1.1:9090/proxies/main-out"
AUTH="Authorization: Bearer diag9090wr"

logger -t wr-boot-stable "start"
: >"$LOG"

sleep 15

if [ ! -s /etc/sing-box/config.json ] && [ -s /etc/sing-box/config.json.ok ]; then
	cp /etc/sing-box/config.json.ok /etc/sing-box/config.json
	logger -t wr-boot-stable "restored config from .ok"
fi
if [ ! -s /etc/sing-box/config.json ] && [ -s /overlay/backups/sing-box-config.ok.json ]; then
	cp /overlay/backups/sing-box-config.ok.json /etc/sing-box/config.json
	cp /etc/sing-box/config.json /etc/sing-box/config.json.ok
	logger -t wr-boot-stable "restored config from overlay"
fi

if ! pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/sing-box start >>"$LOG" 2>&1 || /etc/init.d/podkop start >>"$LOG" 2>&1
	sleep 8
fi

[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh >>"$LOG" 2>&1
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up >>"$LOG" 2>&1
[ -x /usr/bin/wr3000p-podkop-route-fix.sh ] && /usr/bin/wr3000p-podkop-route-fix.sh
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh
[ -x /usr/bin/podkop-yt-routes ] && /usr/bin/podkop-yt-routes 2>/dev/null

printf '%s\n' "$PIN" > /root/kotikey-pinned-main-out
[ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN"

if [ -x /usr/bin/wr3000p-hdrezka-kotikey.sh ]; then
	/usr/bin/wr3000p-hdrezka-kotikey.sh >>"$LOG" 2>&1
	/usr/bin/wr3000p-hdrezka-video-vpn.sh >>"$LOG" 2>&1
fi
[ -x /usr/bin/wr-helper ] && /usr/bin/wr-helper tv-policy >>"$LOG" 2>&1

for API in "$API_LOCAL" "$API_LAN"; do
	wget -qO- --timeout=5 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
		--body-data="{\"name\":\"$PIN\"}" "$API" >/dev/null 2>&1 && break
done
export KOTIKEY_FAILOVER=0
[ -x /usr/bin/podkop-tg-pick.sh ] && /usr/bin/podkop-tg-pick.sh >>"$LOG" 2>&1

logger -t wr-boot-stable "done pin=$PIN sing-box=$(pidof sing-box | wc -l) sbtun=$(ip link show sbtun 2>/dev/null | wc -l)"
exit 0