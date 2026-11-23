#!/bin/sh
# Restore podkop/KotiKey from ON-ROUTER USB backup tree (no cloud tarball needed).
# Uses /mnt/usb/backups — same flash user already maintains.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ -x /etc/init.d/usb-data-mount ] && /etc/init.d/usb-data-mount start
sleep 1

USB="/mnt/usb/backups"
LINKS="$USB/koty-k-kotikey/urltest-preferred.links"
[ -f "$LINKS" ] || { echo "MISSING $LINKS"; exit 1; }

logger -t tr-usb-restore "start"

uci -q delete podkop.main.urltest_proxy_links
n=0
while IFS= read -r line; do
	[ -z "$line" ] && continue
	case "$line" in \#*) continue;; esac
	uci add_list podkop.main.urltest_proxy_links="$line"
	n=$((n + 1))
	[ "$n" -ge 8 ] && break
done < "$LINKS"

uci set podkop.main.proxy_config_type='urltest'
uci commit podkop

# Optional: apply stored UCI snapshot if present on USB
for snap in "$USB"/uci-podkop-*.tar.gz "$USB"/tr3000-*.tar.gz "$USB"/openwrt-*.tar.gz; do
	[ -f "$snap" ] || continue
	echo "Found snapshot $snap — extract etc/config/podkop if inside (manual verify)"
done

if pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop list_update >/tmp/podkop-usb-restore.log 2>&1 || true
else
	/usr/bin/podkop start >/tmp/podkop-usb-restore.log 2>&1 || true
	sleep 8
fi
/usr/bin/podkop-tun-up 2>/dev/null || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true

echo "=== USB RESTORE VERIFY ==="
test -f "$LINKS" && echo "kotikey: OK"
uci get podkop.main.urltest_proxy_links | tr ' ' '\n' | head -4
pidof sing-box || true
nslookup instagram.com 127.0.0.42 2>/dev/null | grep Address | tail -2
logger -t tr-usb-restore "done"