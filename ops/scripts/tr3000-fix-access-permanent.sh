#!/bin/sh
# TR3000, run once as root from LAN. Makes remote access survive podkop/sing-box
# restarts and reboots, snapshots the working config to USB, repairs the LuCI
# Tailscale page. Safe to re-run.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"
AGENT_TS_IP="100.66.76.102"

fetch() { curl -fsSL "$1" -o "$2" 2>/dev/null || wget -qO "$2" "$1"; }

echo "=== 0) BEFORE: where do replies to the agent go? ==="
ip route get "$AGENT_TS_IP" 2>&1
ip rule show | head -12
echo "-- table podkop:"; ip route show table podkop 2>&1
echo "-- main route for tailnet:"; ip route show 100.64.0.0/10 2>&1
echo "-- nft mangle_output head:"; nft list chain inet PodkopTable mangle_output 2>/dev/null | head -8

echo
echo "=== 1) install the tailnet pin ==="
fetch "$BASE/tr3000-tailnet-pin.sh" /usr/bin/tr3000-tailnet-pin.sh || { echo "FETCH FAILED"; exit 1; }
chmod +x /usr/bin/tr3000-tailnet-pin.sh
/usr/bin/tr3000-tailnet-pin.sh
echo "pin log:"; tail -8 /tmp/tailnet-pin.log 2>/dev/null

echo
echo "=== 2) run it every minute ==="
CRON=/etc/crontabs/root
touch "$CRON"
grep -q 'tr3000-tailnet-pin' "$CRON" || echo '* * * * * /usr/bin/tr3000-tailnet-pin.sh >/dev/null 2>&1' >>"$CRON"
grep -q 'podkop-guard' "$CRON" || echo '*/4 * * * * /usr/bin/podkop-guard.sh >/dev/null 2>&1' >>"$CRON"
/etc/init.d/cron restart
grep -E 'tailnet-pin|podkop-guard' "$CRON"

echo
echo "=== 3) run it on boot ==="
cat > /etc/init.d/tailnet-pin << 'EOF'
#!/bin/sh /etc/rc.common
START=98
boot() { (sleep 40; /usr/bin/tr3000-tailnet-pin.sh) & }
start() { /usr/bin/tr3000-tailnet-pin.sh; }
EOF
chmod +x /etc/init.d/tailnet-pin
/etc/init.d/tailnet-pin enable
ls -l /etc/rc.d/ | grep tailnet-pin

echo
echo "=== 4) run it whenever the tunnel comes up (the moment access used to die) ==="
touch /usr/bin/podkop-tun-up
chmod +x /usr/bin/podkop-tun-up
grep -q 'tr3000-tailnet-pin' /usr/bin/podkop-tun-up || \
	echo '/usr/bin/tr3000-tailnet-pin.sh' >> /usr/bin/podkop-tun-up
tail -3 /usr/bin/podkop-tun-up

echo
echo "=== 5) AFTER: replies to the agent must leave via tailscale0 ==="
ip route get "$AGENT_TS_IP" 2>&1
ip rule show | grep -E '^(90|105):' 2>&1

echo
echo "=== 6) snapshot the working config to the USB stick ==="
fetch "$BASE/tr3000-backup-to-usb.sh" /tmp/backup-to-usb.sh && sh /tmp/backup-to-usb.sh

echo
echo "=== 7) repair the LuCI Tailscale page (404 on view/tailscale.js) ==="
if [ ! -f /www/luci-static/resources/view/tailscale.js ]; then
	if command -v apk >/dev/null 2>&1; then
		apk update >/dev/null 2>&1
		apk fix luci-app-tailscale 2>&1 | tail -2 || apk add luci-app-tailscale 2>&1 | tail -2
	else
		opkg update >/dev/null 2>&1
		opkg install --force-reinstall luci-app-tailscale 2>&1 | tail -2
	fi
else
	echo "view file present, only clearing the cache"
fi
rm -rf /tmp/luci-modulecache/* 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null
ls -l /www/luci-static/resources/view/tailscale.js 2>&1

echo
echo "=== 8) health ==="
echo "youtube=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null)"
echo "instagram=$(curl -4 -sS -m12 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)"
echo "telegram=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://web.telegram.org/ 2>/dev/null)"
netstat -lnt 2>/dev/null | grep ':2222 '
echo "=== DONE ==="
