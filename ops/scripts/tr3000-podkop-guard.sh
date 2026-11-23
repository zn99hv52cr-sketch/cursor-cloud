#!/bin/sh
# TR3000: keep blocked sites reachable. Restores the podkop route table when it is
# empty and re-pins main-out to a node that actually passes YouTube and Telegram
# (API latency alone lies — a node can answer /delay and still reset TLS).
# Install: /usr/bin/podkop-guard.sh + cron every 4 min.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
API=http://192.168.2.1:9090/proxies/main-out

[ "$(ip route show table podkop | wc -l)" -lt 3 ] && /usr/bin/podkop-restore-table.sh

ok() {
	yt=$(curl -4 -sS -m8 -o /dev/null -w "%{http_code}" https://www.youtube.com/generate_204 2>/dev/null)
	tg=$(curl -4 -sS -m8 -o /dev/null -w "%{http_code}" https://web.telegram.org/ 2>/dev/null)
	[ "$yt" = "204" ] && [ "$tg" = "200" ]
}

ok && exit 0

for n in 1 3 2 4 5 6 7 8; do
	wget -qO- --timeout=5 --method=PUT --body-data="{\"name\":\"main-${n}-out\"}" \
		--header="Content-Type: application/json" "$API" >/dev/null 2>&1
	sleep 2
	ok && logger -t podkop-guard "pinned main-${n}-out" && exit 0
done

logger -t podkop-guard "no healthy node"
