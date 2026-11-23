#!/bin/sh
# WR3000P: restore podkop.main urltest links from local KotiKey backup (overlay/root, not TR USB path).
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
for LINKS in /root/koty-k-kotikey/urltest-preferred.links \
	/overlay/backups/koty-k-kotikey/urltest-preferred.links \
	/mnt/usb/backups/koty-k-kotikey/urltest-preferred.links; do
	[ -f "$LINKS" ] && break
done
[ -f "$LINKS" ] || { echo "NO_KOTIKEY_LINKS"; exit 1; }
echo "USING $LINKS"

uci -q delete podkop.main.urltest_proxy_links
while IFS= read -r line; do
	[ -z "$line" ] && continue
	case "$line" in \#*) continue;; esac
	uci add_list podkop.main.urltest_proxy_links="$line"
done < "$LINKS"
uci set podkop.main.proxy_config_type='urltest'
uci commit podkop
/usr/bin/podkop start >/tmp/wr-koti-restore.log 2>&1 || true
sleep 10
CFG=/etc/sing-box/config.json
if [ -s "$CFG" ] && command -v jq >/dev/null 2>&1; then
	jq '(.outbounds[] | select(.type=="vless" and (.tls.reality.enabled? == true))) |= del(.transport)' \
		"$CFG" > /tmp/sb-koti.json 2>/dev/null && \
		sing-box check -c /tmp/sb-koti.json 2>/dev/null && \
		cp /tmp/sb-koti.json "$CFG" && cp "$CFG" /etc/sing-box/config.json.ok
fi
/usr/bin/podkop-tun-up 2>/dev/null || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh
[ -x /usr/bin/wr3000p-podkop-route-fix.sh ] && /usr/bin/wr3000p-podkop-route-fix.sh
AUTH="Authorization: Bearer diag9090wr"
[ -x /usr/bin/podkop-tg-pick.sh ] && /usr/bin/podkop-tg-pick.sh || true
echo "KOTIKEY_RESTORED from $LINKS"