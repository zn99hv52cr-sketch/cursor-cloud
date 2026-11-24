#!/bin/sh
# WR3000P: keep main-out on a node where YouTube + Telegram work (via Clash delay, not WAN curl).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
exec 9>/var/lock/podkop-tg-pick.lock
flock -n 9 || exit 0
API=http://127.0.0.1:9090/proxies/main-out
AUTH="Authorization: Bearer diag9090wr"
MAX_MS=8500

delay_ms() {
	tag=$1
	url=$2
	resp=$(wget -qO- --timeout=18 --header="$AUTH" \
		"http://127.0.0.1:9090/proxies/${tag}/delay?timeout=8000&url=${url}" 2>/dev/null) || return 1
	echo "$resp" | grep -o '"delay":[0-9]*' | head -1 | sed 's/"delay"://'
}

node_ok() {
	tag=$1
	yt=$(delay_ms "$tag" 'https%3A%2F%2Fwww.youtube.com%2Fgenerate_204') || return 1
	tg=$(delay_ms "$tag" 'https%3A%2F%2Fweb.telegram.org%2F') || return 1
	[ -n "$yt" ] && [ -n "$tg" ] && [ "$yt" -lt "$MAX_MS" ] && [ "$tg" -lt "$MAX_MS" ]
}

pin() {
	wget -qO- --timeout=4 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
		--body-data="{\"name\":\"$1\"}" "$API" >/dev/null 2>&1 || true
}

save_pin() {
	printf '%s\n' "$1" > /root/kotikey-pinned-main-out
}

PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
if [ -n "$PIN" ]; then
	pin "$PIN"
	sleep 1
	if node_ok "$PIN"; then
		logger -t podkop-tg-pick "keep $PIN"
		exit 0
	fi
	logger -t podkop-tg-pick "pinned $PIN failed probes"
fi

for n in 4 3 1 5 6 7 8; do
	tag="main-${n}-out"
	pin "$tag"
	sleep 1
	if node_ok "$tag"; then
		save_pin "$tag"
		logger -t podkop-tg-pick "OK $tag"
		exit 0
	fi
done
[ -n "$PIN" ] && pin "$PIN"
exit 1