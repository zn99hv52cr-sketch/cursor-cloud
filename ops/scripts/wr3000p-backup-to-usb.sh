#!/bin/sh
# WR3000P: snapshot working KotiKey config to USB (and /overlay/backups fallback).
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

mkdir -p /mnt/usb
if ! grep -q " /mnt/usb " /proc/mounts 2>/dev/null; then
	[ -b /dev/sda1 ] && mount -t ext4 /dev/sda1 /mnt/usb 2>/dev/null \
		|| mount -t vfat /dev/sda1 /mnt/usb 2>/dev/null \
		|| mount /dev/sda1 /mnt/usb 2>/dev/null || true
fi

USB_ROOT="/mnt/usb/backups"
OVERLAY_ROOT="/overlay/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
AUTH="Authorization: Bearer diag9090wr"

for ROOT in "$USB_ROOT" "$OVERLAY_ROOT"; do
	[ "$ROOT" = "$USB_ROOT" ] && [ ! -d /mnt/usb/backups ] 2>/dev/null && continue
	DIR="$ROOT/archive/wr3000p-WORKING-$STAMP"
	mkdir -p "$DIR/uci" "$DIR/usr-bin" "$DIR/dnsmasq.d" "$DIR/live" "$DIR/koty-k-kotikey"
	cp -a /etc/config "$DIR/etc-config" 2>/dev/null || true
	uci export podkop >"$DIR/uci/podkop.uci" 2>/dev/null || true
	uci export dhcp >"$DIR/uci/dhcp.uci" 2>/dev/null || true
	cp /etc/sing-box/config.json "$DIR/config.json" 2>/dev/null || true
	cp /etc/sing-box/config.json.ok "$DIR/config.json.ok" 2>/dev/null || true
	[ -f /root/koty-k-kotikey/urltest-preferred.links ] && \
		cp /root/koty-k-kotikey/urltest-preferred.links "$DIR/koty-k-kotikey/"
	[ -f /root/kotikey-pinned-main-out ] && cp /root/kotikey-pinned-main-out "$DIR/"
	for f in /usr/bin/podkop-tun-up /usr/bin/podkop-restore-mangle.sh \
		/usr/bin/wr3000p-* /usr/bin/podkop-tg-pick.sh /usr/bin/tv-yt-policy /usr/bin/wr-helper; do
		[ -f "$f" ] && cp "$f" "$DIR/usr-bin/" 2>/dev/null || true
	done
	cp /etc/dnsmasq.d/*.conf "$DIR/dnsmasq.d/" 2>/dev/null || true
	cp /etc/crontabs/root "$DIR/crontab-root" 2>/dev/null || true
	nft list ruleset >"$DIR/live/nft.ruleset" 2>/dev/null || true
	ip rule >"$DIR/live/ip-rule.txt" 2>/dev/null || true
	ip route >"$DIR/live/ip-route.txt" 2>/dev/null || true
	ip route show table podkop >"$DIR/live/ip-route-podkop.txt" 2>/dev/null || true
	wget -qO- --timeout=4 --header="$AUTH" http://127.0.0.1:9090/proxies/main-out \
		>"$DIR/live/clash-main-out.json" 2>/dev/null || true
	NOW=$(grep -o '"now":"[^"]*"' "$DIR/live/clash-main-out.json" 2>/dev/null | head -1)
	Yt=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null || echo 0)
	cat >"$DIR/HEALTH.txt" << EOF
WR3000P snapshot $STAMP $(date)
pinned=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
$NOW
youtube=$Yt
EOF
	tar -czf "$ROOT/archive/wr3000p-WORKING-$STAMP.tar.gz" -C "$ROOT/archive" "wr3000p-WORKING-$STAMP" 2>/dev/null || true
	echo "$DIR" >"$ROOT/CURRENT-WORKING.txt"
	logger -t wr-backup "saved $DIR"
done

echo "BACKUP_OK stamp=$STAMP usb=$([ -d $USB_ROOT/archive ] && echo yes || echo no)"