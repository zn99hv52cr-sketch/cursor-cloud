#!/bin/sh
# WR3000P: держим ноду, на которой YouTube реально открывается. Не пинаем отсутствующий тег.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
exec 9>/var/lock/podkop-tg-pick.lock
flock -n 9 || exit 0
API=http://127.0.0.1:9090/proxies/main-out
AUTH="Authorization: Bearer diag9090wr"
YT='https%3A%2F%2Fwww.youtube.com%2Fgenerate_204'
KEEP_MS=1200
MAX_MS=8000

delay_ms() {
	wget -qO- --timeout=14 --header="$AUTH" \
		"http://127.0.0.1:9090/proxies/$1/delay?timeout=7000&url=$YT" 2>/dev/null \
		| grep -o '"delay":[0-9]*' | head -1 | sed 's/"delay"://'
}

pin_live() {
	wget -qO- --timeout=4 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
		--body-data="{\"name\":\"$1\"}" "$API" >/dev/null 2>&1 || true
	printf '%s\n' "$1" > /root/kotikey-pinned-main-out
	logger -t podkop-tg-pick "pin $1"
}

ALL=$(wget -qO- --timeout=5 --header="$AUTH" "$API" 2>/dev/null | jq -r '.all[]?' 2>/dev/null)
[ -n "$ALL" ] || exit 0

order() {
	printf '%s\n' "$ALL" | grep -v '^main-2-out$' | grep -v 'urltest'
	printf '%s\n' "$ALL" | grep '^main-2-out$'
}

PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
if printf '%s\n' "$ALL" | grep -qx "$PIN"; then
	ms=$(delay_ms "$PIN")
	if [ -n "$ms" ] && [ "$ms" -lt "$KEEP_MS" ]; then
		pin_live "$PIN"
		exit 0
	fi
	logger -t podkop-tg-pick "pinned $PIN youtube fail (${ms:-timeout})"
else
	logger -t podkop-tg-pick "pinned ${PIN:-empty} not in selector"
fi

rm -f /tmp/wr-yt-best
order | while read -r tag; do
	[ -n "$tag" ] || continue
	ms=$(delay_ms "$tag")
	[ -n "$ms" ] && [ "$ms" -lt "$MAX_MS" ] && [ "$ms" -lt "$best_ms" ] || continue
	best=$tag
	best_ms=$ms
	printf '%s %s\n' "$best_ms" "$best" > /tmp/wr-yt-best
done
read -r best_ms best < /tmp/wr-yt-best 2>/dev/null || exit 1
[ -n "$best" ] || exit 1
pin_live "$best"
logger -t podkop-tg-pick "fastest $best ${best_ms}ms"
exit 0