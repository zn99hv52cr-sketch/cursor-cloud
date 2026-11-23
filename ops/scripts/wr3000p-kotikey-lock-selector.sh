#!/bin/sh
# KotiKey on WR: urltest in main-out auto-picks dead nodes — drop it from selector.
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok
[ -s "$CFG" ] && command -v jq >/dev/null 2>&1 || exit 0
old=$(md5sum "$CFG" 2>/dev/null | awk '{print $1}')
jq '
  (.outbounds[] | select(.type=="vless" and (.tls.reality.enabled? == true))) |= del(.transport)
  |
  (.outbounds[] | select(.tag=="main-out" and .type=="selector")) |= (
    .outbounds |= map(select(. != "main-urltest-out"))
  )
' "$CFG" > /tmp/sb-lock.json 2>/dev/null || exit 0
sing-box check -c /tmp/sb-lock.json >/dev/null 2>&1 || exit 0
new=$(md5sum /tmp/sb-lock.json 2>/dev/null | awk '{print $1}')
[ "$old" = "$new" ] && rm -f /tmp/sb-lock.json && exit 0
mv /tmp/sb-lock.json "$CFG"
cp -a "$CFG" "$OK"
if pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/sing-box restart >/dev/null 2>&1 || true
	sleep 2
	/usr/bin/wr3000p-podkop-route-fix.sh 2>/dev/null || true
	/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
fi