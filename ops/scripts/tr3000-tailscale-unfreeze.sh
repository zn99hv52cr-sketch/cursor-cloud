#!/bin/sh
# TR3000, run once as root from LAN. Takes tailscale's own traffic out of podkop,
# revives the frozen control connection, installs a watchdog so it cannot freeze
# unnoticed again, then snapshots the working config to USB.
#
# Diagnosis this is based on: the router kept its DERP socket (disco pings
# answered) while its netmap went stale, so peers showed "offline, last seen
# 41m ago" and no TCP session completed in either direction. tailscaled's own
# sockets were being marked for the podkop table and resolved through fakeip.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"
AGENT_TS_IP="100.66.76.102"

fetch() { curl -fsSL "$1" -o "$2" 2>/dev/null || wget -qO "$2" "$1"; }

echo "=== 0) BEFORE ==="
tailscale status 2>/dev/null | grep -iE 'cursor-cloud|cudy-wr3000p' || echo "(agent node not listed)"
echo "-- fakeip hits from the router itself (this is the smoking gun):"
nft list chain inet PodkopTable mangle_output 2>/dev/null | grep '198.18.0.0/15'

echo
echo "=== 1) install the pin (tailscale mark bypass + tailnet routes + direct DNS) ==="
for s in tr3000-tailnet-pin.sh tr3000-tailscale-watchdog.sh; do
	fetch "$BASE/$s" "/usr/bin/$s" || { echo "FETCH FAILED: $s"; exit 1; }
	chmod +x "/usr/bin/$s"
done
/usr/bin/tr3000-tailnet-pin.sh
tail -12 /tmp/tailnet-pin.log 2>/dev/null
echo "-- mangle_output now starts with:"
nft list chain inet PodkopTable mangle_output 2>/dev/null | sed -n '3,7p'

echo
echo "=== 2) revive the control connection ==="
tailscale debug prefs >/root/tailscale-prefs-before.json 2>/dev/null
/etc/init.d/tailscale restart >/dev/null 2>&1
sleep 25
/usr/bin/tr3000-tailnet-pin.sh
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null
tailscale status 2>&1 | head -4
if tailscale status 2>&1 | grep -qi 'logged out\|NeedsLogin'; then
	echo "!!! TAILSCALE LOGGED OUT — re-auth needed, prefs saved in /root/tailscale-prefs-before.json"
fi

echo
echo "=== 3) VERIFY both directions ==="
tailscale status 2>/dev/null | grep -i 'cursor-cloud' || echo "(agent node still not listed)"
tailscale ping -c 3 "$AGENT_TS_IP" 2>&1 | tail -3
curl -sS -m 8 -o /dev/null -w "router->agent tcp 9999: http=%{http_code}\n" "http://$AGENT_TS_IP:9999/" 2>&1 | tail -1

echo
echo "=== 4) watchdog every 5 minutes ==="
CRON=/etc/crontabs/root
touch "$CRON"
grep -q 'tr3000-tailscale-watchdog' "$CRON" || \
	echo '*/5 * * * * /usr/bin/tr3000-tailscale-watchdog.sh >/dev/null 2>&1' >>"$CRON"
grep -q 'tr3000-tailnet-pin' "$CRON" || \
	echo '* * * * * /usr/bin/tr3000-tailnet-pin.sh >/dev/null 2>&1' >>"$CRON"
sed -i '/tailscale set --ssh=false/d' "$CRON"
/etc/init.d/cron restart
grep -E 'tailnet-pin|watchdog|podkop-guard' "$CRON"

echo
echo "=== 5) snapshot the working config to USB (script was corrupted before, now fixed) ==="
fetch "$BASE/tr3000-backup-to-usb.sh" /tmp/backup-to-usb.sh && sh /tmp/backup-to-usb.sh

echo
echo "=== 6) blocked sites still fine? ==="
echo "youtube=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null)"
echo "instagram=$(curl -4 -sS -m12 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)"
echo "telegram=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://web.telegram.org/ 2>/dev/null)"
echo "=== DONE ==="
