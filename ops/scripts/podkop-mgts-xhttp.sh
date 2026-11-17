#!/bin/sh
# Optional: patch vless outbounds for xHTTP via Cloudflare (path /xh/).
# podkop UCI cannot express type=http; apply after podkop start when enabled.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
CFG=/etc/sing-box/config.json
FLAG=/etc/config/podkop-mgts-xhttp
MARK=/tmp/podkop-mgts-xhttp-restart

[ -f "$FLAG" ] || exit 0
[ -s "$CFG" ] || exit 1
rm -f "$MARK"

jq '
  .outbounds |= map(
    if .type == "vless" then
      .transport = {
        "type": "http",
        "path": "/xh/",
        "host": "vpn2.sharpmaind.ru"
      }
    else . end
  )
' "$CFG" > /tmp/sb.xhttp.json || exit 1
sing-box check -c /tmp/sb.xhttp.json >/dev/null 2>&1 || exit 1
cmp -s /tmp/sb.xhttp.json "$CFG" && exit 0
cp /tmp/sb.xhttp.json "$CFG"
cp "$CFG" /etc/sing-box/config.json.ok 2>/dev/null || true
touch "$MARK"
logger -t podkop-mgts-xhttp "vless transport -> xhttp /xh/"
[ -f "$MARK" ] || exit 0
rm -f "$MARK"
kill $(pidof sing-box) 2>/dev/null
sleep 1
sing-box run -c "$CFG" -D /usr/share/sing-box >/dev/null 2>&1 &
sleep 2
/usr/bin/podkop-tun-up >/dev/null 2>&1 || true