#!/bin/sh
# WR3000P: не гонять Telegram через podkop VLESS (медиа 12–30 KB/s на CPU роутера).
# MTProxy Telemt на VPS :8443 — в настройках Telegram на телефоне/ПК.
# Run: tailscale ssh root@100.104.207.62 'sh -s' < ops/scripts/wr3000p-telegram-no-vless.sh
set -e

uci del_list podkop.main.community_lists='telegram' 2>/dev/null || true
for d in telegram.org telegram.me td.telegram.org telegram.dog core.telegram.org t.me telesco.pe; do
	uci del_list podkop.main.user_domains="$d" 2>/dev/null || true
done

uci commit podkop
/etc/init.d/podkop restart
sleep 5
if logread 2>/dev/null | tail -20 | grep -qi 'configuration is unchanged'; then
	/etc/init.d/sing-box restart
fi
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up 2>/dev/null || true

# один sing-box
SB=$(pgrep -f '/usr/bin/sing-box' | wc -l)
echo "sing-box processes: $SB (expect 1)"

echo "=== DNS (198.20.x.x = still in tunnel via other lists) ==="
for d in rutracker.org api.telegram.org; do
	echo "-- $d"
	nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print; exit}'
done

echo "community_lists=$(uci get podkop.main.community_lists 2>/dev/null || echo none)"
