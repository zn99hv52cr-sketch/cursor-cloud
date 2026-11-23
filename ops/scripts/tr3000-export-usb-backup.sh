#!/bin/sh
# Pack EXISTING backups from USB (/mnt/usb/backups) — KotiKey + whatever is on flash.
# Run ON Cudy as root. Output: /tmp/tr3000-usb-export-*.tar.gz for scp → TG bot.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ -x /etc/init.d/usb-data-mount ] && /etc/init.d/usb-data-mount start
sleep 1

USB_ROOT="/mnt/usb/backups"
[ -d "$USB_ROOT" ] || { echo "ERROR: $USB_ROOT not mounted"; ls -la /mnt/usb 2>/dev/null; exit 1; }

echo "=== USB /mnt/usb/backups ==="
ls -la "$USB_ROOT"
echo ""
find "$USB_ROOT" -maxdepth 3 -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.gz' \) 2>/dev/null | head -20
echo ""

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/tr3000-usb-export-$STAMP.tar.gz"

# If there is already a ready archive on USB — copy newest (working golden backup).
ARCH=""
for pattern in "*.tar.gz" "*.tgz"; do
	found="$(find "$USB_ROOT" -type f -name "$pattern" 2>/dev/null | while read -r p; do
		echo "$(stat -c %Y "$p" 2>/dev/null || echo 0) $p"
	done | sort -n | tail -1 | cut -d' ' -f2-)"
	[ -n "$found" ] && ARCH="$found" && break
done

if [ -n "$ARCH" ] && [ -f "$ARCH" ]; then
	cp "$ARCH" "$OUT"
	echo "USED_EXISTING_ARCHIVE=$ARCH"
else
	# Pack entire backups tree (includes koty-k-kotikey/)
	tar -czf "$OUT" -C /mnt/usb backups
	echo "PACKED_TREE=$USB_ROOT"
fi

# Sanity
test -f "$USB_ROOT/koty-k-kotikey/urltest-preferred.links" \
	&& echo "KOTIKEY_LINKS=OK" || echo "KOTIKEY_LINKS=MISSING"

ls -la "$OUT"
echo ""
echo "BACKUP_READY $OUT"
echo "To Telegram:"
echo "  scp root@192.168.2.1:$OUT ."
echo "  scp $OUT root@193.124.224.248:/tmp/"
echo "  CHAT_ID=186409737 /tmp/tr3000-send-backup-telegram.sh /tmp/$(basename "$OUT")"