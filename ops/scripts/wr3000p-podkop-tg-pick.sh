#!/bin/sh
# WR3000P: pin KotiKey node when YouTube + Telegram work (main-3 often best for TG).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
exec 9>/var/lock/podkop-tg-pick.lock
flock -n 9 || exit 0
API=http://127.0.0.1:9090/proxies/main-out
AUTH="Authorization: Bearer diag9090wr"
ok() {
	yt=$(curl -4 -sS -m 8 -o /dev/null -w "%{http_code}" https://www.youtube.com/generate_204 2>/dev/null) || yt=0
	tg=$(curl -4 -sS -m 8 -o /dev/null -w "%{http_code}" https://web.telegram.org/ 2>/dev/null) || tg=0
	[ "$yt" = "204" ] && [ "$tg" = "200" ]
}
pin() {
	wget -qO- --timeout=4 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
		--body-data="{\"name\":\"$1\"}" "$API" >/dev/null 2>&1 || true
}
PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
[ -n "$PIN" ] && pin "$PIN" && sleep 2 && ok && exit 0
for n in 1 3 4 2 5 6 7 8; do
	pin "main-${n}-out"
	sleep 2
	ok && logger -t podkop-tg-pick "OK main-${n}-out" && exit 0
done
pin "main-3-out"
exit 1