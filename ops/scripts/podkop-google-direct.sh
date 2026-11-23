#!/bin/sh
# Deprecated: MGTS blocks YouTube SNI on direct WAN; tunnel required.
# This script only strips mistaken direct-YouTube rules if podkop left them behind.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
CFG=/etc/sing-box/config.json
LOCK=/var/lock/sing-box-config.lock
OK=/etc/sing-box/config.json.ok
MARK=/tmp/podkop-google-direct-restart

[ -s "$CFG" ] || cp "$OK" "$CFG" 2>/dev/null || exit 1
rm -f "$MARK"

(
  flock -n 9 || exit 0
  jq '
    .dns.rules |= map(select(
      (.server? != "dns-server") or ((.domain_suffix? // [] | index("youtube.com")) | not)
    ))
    | .route.rules |= map(select(
      (.outbound? != "direct-out") or ((.domain_suffix? // [] | index("youtube.com")) | not)
    ))
  ' "$CFG" > /tmp/sb.nogoogle.json || exit 1
  sing-box check -c /tmp/sb.nogoogle.json >/dev/null 2>&1 || exit 0
  cmp -s /tmp/sb.nogoogle.json "$CFG" && exit 0
  cp /tmp/sb.nogoogle.json "$CFG"
  cp "$CFG" "$OK" 2>/dev/null || true
  touch "$MARK"
  logger -t podkop-google-direct "removed broken direct-YouTube rules"
) 9>"$LOCK"

[ -f "$MARK" ] || exit 0
rm -f "$MARK"
kill $(pidof sing-box) 2>/dev/null
sleep 1
sing-box run -c "$CFG" -D /usr/share/sing-box >/dev/null 2>&1 &
sleep 2
/usr/bin/podkop-tun-up >/dev/null 2>&1 || true