#!/bin/sh
# WR3000P: удерживаем закреплённую KotiKey-ноду. Failover выключен по умолчанию.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
exec 9>/var/lock/podkop-tg-pick.lock
flock -n 9 || exit 0
API=http://127.0.0.1:9090/proxies/main-out
AUTH="Authorization: Bearer diag9090wr"
MAX_MS=12000

PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
[ -n "$PIN" ] || PIN="main-4-out"
# main-2-out известна мёртвой для Google — не использовать.
case "$PIN" in main-2-out) PIN=main-4-out; printf '%s\n' "$PIN" > /root/kotikey-pinned-main-out;; esac

pin() {
	wget -qO- --timeout=4 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
		--body-data="{\"name\":\"$1\"}" "$API" >/dev/null 2>&1 || true
}

now=$(wget -qO- --timeout=4 --header="$AUTH" "$API" 2>/dev/null \
	| grep -o '"now":"[^"]*"' | head -1 | sed 's/"now":"//;s/"//')
case "$now" in main-2-out|""|*urltest*) pin "$PIN"; logger -t podkop-tg-pick "fix invalid ${now:-empty} -> $PIN";; esac
if [ -n "$now" ] && [ "$now" != "$PIN" ]; then
	pin "$PIN"
	logger -t podkop-tg-pick "drift $now -> $PIN"
fi

# Failover только если явно: touch /root/kotikey-allow-failover
if [ "$KOTIKEY_FAILOVER" = "1" ] || [ -f /root/kotikey-allow-failover ]; then
	delay_ok() {
		tag=$1
		url=$2
		resp=$(wget -qO- --timeout=16 --header="$AUTH" \
			"http://127.0.0.1:9090/proxies/${tag}/delay?timeout=8000&url=${url}" 2>/dev/null) || return 1
		ms=$(echo "$resp" | grep -o '"delay":[0-9]*' | head -1 | sed 's/"delay"://')
		[ -n "$ms" ] && [ "$ms" -lt "$MAX_MS" ]
	}
	if ! delay_ok "$PIN" 'https%3A%2F%2Fwww.youtube.com%2Fgenerate_204'; then
		for tag in main-4-out main-3-out main-1-out main-5-out; do
			[ "$tag" = "$PIN" ] && continue
			pin "$tag"
			sleep 1
			if delay_ok "$tag" 'https%3A%2F%2Fwww.youtube.com%2Fgenerate_204'; then
				printf '%s\n' "$tag" > /root/kotikey-pinned-main-out
				logger -t podkop-tg-pick "failover -> $tag"
				exit 0
			fi
		done
		pin "$PIN"
	fi
fi
exit 0