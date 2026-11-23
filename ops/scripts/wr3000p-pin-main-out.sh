#!/bin/sh
# Pin KotiKey node after boot (default: read /root/kotikey-pinned-main-out).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
PIN="${1:-$(cat /root/kotikey-pinned-main-out 2>/dev/null)}"
[ -n "$PIN" ] || exit 0
API=http://127.0.0.1:9090/proxies/main-out
AUTH="Authorization: Bearer diag9090wr"
printf '%s\n' "$PIN" > /root/kotikey-pinned-main-out
wget -qO- --timeout=4 --method=PUT --header="$AUTH" --header="Content-Type: application/json" \
	--body-data="{\"name\":\"$PIN\"}" "$API" >/dev/null 2>&1 || true
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok
if [ -s "$CFG" ] && command -v jq >/dev/null 2>&1; then
	jq --arg p "$PIN" '(.outbounds[] | select(.tag=="main-out" and .type=="selector")) |= (.default = $p)' \
		"$CFG" > /tmp/sb-pin.json 2>/dev/null && sing-box check -c /tmp/sb-pin.json 2>/dev/null && \
		cp /tmp/sb-pin.json "$CFG" && cp "$CFG" "$OK"
fi
logger -t wr-pin "main-out=$PIN"