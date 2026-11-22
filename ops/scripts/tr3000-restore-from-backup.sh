#!/bin/sh
# Restore TR3000 from tarball created by tr3000-backup-full.sh. Run ON router as root.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
ARCHIVE="${1:-}"
[ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || { echo "Usage: $0 /tmp/tr3000-backup-YYYYMMDD-HHMMSS.tar.gz"; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
WORKDIR="/tmp/tr3000-restore-$STAMP"
mkdir -p "$WORKDIR"
tar -xzf "$ARCHIVE" -C "$WORKDIR"
BUNDLE="$(find "$WORKDIR" -maxdepth 1 -type d -name 'tr3000-backup-*' | head -1)"
[ -n "$BUNDLE" ] || { echo "bad archive layout"; exit 1; }

logger -t tr-restore "start from $ARCHIVE"

if [ -d "$BUNDLE/etc-config" ]; then
	for f in network firewall dhcp podkop dropbear tailscale; do
		[ -f "$BUNDLE/etc-config/$f" ] && cp "$BUNDLE/etc-config/$f" "/etc/config/$f"
	done
	uci commit network 2>/dev/null || true
	uci commit firewall 2>/dev/null || true
	uci commit dhcp 2>/dev/null || true
	uci commit podkop 2>/dev/null || true
	uci commit dropbear 2>/dev/null || true
	uci commit tailscale 2>/dev/null || true
fi

if [ -d "$BUNDLE/koti-k-kotikey" ]; then
	mkdir -p /mnt/usb/backups
	cp -a "$BUNDLE/koti-k-kotikey" /mnt/usb/backups/
	logger -t tr-restore "kotikey restored to USB"
fi

[ -f "$BUNDLE/podkop-tun-up" ] && cp "$BUNDLE/podkop-tun-up" /usr/bin/podkop-tun-up && chmod +x /usr/bin/podkop-tun-up
[ -f "$BUNDLE/podkop-restore-mangle.sh" ] && cp "$BUNDLE/podkop-restore-mangle.sh" /usr/bin/ && chmod +x /usr/bin/podkop-restore-mangle.sh
[ -f "$BUNDLE/tr3000-wan-recover" ] && cp "$BUNDLE/tr3000-wan-recover" /usr/bin/ && chmod +x /usr/bin/tr3000-wan-recover

grep -q podkop-restore-mangle /usr/bin/podkop-tun-up 2>/dev/null || echo '/usr/bin/podkop-restore-mangle.sh' >> /usr/bin/podkop-tun-up

[ -d "$BUNDLE/sing-box" ] && cp -a "$BUNDLE/sing-box" /tmp/ 2>/dev/null || true
[ -d "$BUNDLE/sysctl.d" ] && cp "$BUNDLE/sysctl.d/"* /etc/sysctl.d/ 2>/dev/null || true
sysctl -p /etc/sysctl.d/99-vpn-bulk.conf 2>/dev/null || true
sysctl -p /etc/sysctl.d/99-ios-wifi.conf 2>/dev/null || true

/etc/init.d/network reload 2>/dev/null || true
/etc/init.d/firewall reload 2>/dev/null || true
/etc/init.d/dnsmasq restart 2>/dev/null || true
/etc/init.d/dropbear restart 2>/dev/null || true

if pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop list_update >/tmp/podkop-restore-list.log 2>&1 || true
else
	/usr/bin/podkop start >/tmp/podkop-restore-start.log 2>&1 || true
	sleep 8
fi
/usr/bin/podkop-tun-up 2>/dev/null || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

echo "=== RESTORE VERIFY ==="
pidof sing-box || true
nslookup instagram.com 127.0.0.42 2>/dev/null | grep Address | tail -2
nft list chain inet PodkopTable mangle 2>/dev/null | grep counter | head -2
test -f /mnt/usb/backups/koty-k-kotikey/urltest-preferred.links && echo "kotikey links: OK" || echo "kotikey links: MISSING"
logger -t tr-restore "done"