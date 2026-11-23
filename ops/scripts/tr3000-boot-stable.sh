#!/bin/sh
# TR3000 stable boot stack: podkop/DNS/mangle, pin main-5-out, verify instagram.
# NO tailscale restart, NO full podkop restart if sing-box up.
# Deploy: /usr/bin/tr3000-boot-stable.sh
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# The sing-box controller binds the LAN address only; 127.0.0.1 is refused.
API="${PODKOP_API:-http://192.168.2.1:9090/proxies/main-out}"
OUT="${PODKOP_OUT:-main-1-out}"
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

logger -t tr-boot-stable "start out=$OUT"

[ -x /etc/init.d/usb-data-mount ] && /etc/init.d/usb-data-mount start
sleep 1

curl -fsSL "$BASE/tr3000-podkop-restore-mangle.sh" -o /usr/bin/podkop-restore-mangle.sh 2>/dev/null && chmod +x /usr/bin/podkop-restore-mangle.sh || true
grep -q podkop-restore-mangle /usr/bin/podkop-tun-up 2>/dev/null || echo '/usr/bin/podkop-restore-mangle.sh' >> /usr/bin/podkop-tun-up

LAN="$(uci get network.lan.ipaddr 2>/dev/null || echo 192.168.2.1)"
uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server='127.0.0.42#53'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localservice='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 2
killall -HUP dnsmasq 2>/dev/null || true

if ! pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop start >/tmp/podkop-boot-stable.log 2>&1 || true
	sleep 10
else
	/usr/bin/podkop list_update >/tmp/podkop-boot-stable.log 2>&1 || true
	sleep 3
fi

/usr/bin/podkop-tun-up >/tmp/tun-boot-stable.log 2>&1 || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
/usr/bin/podkop-restore-table.sh 2>/dev/null || true
rm -f /tmp/sing-box/cache.db 2>/dev/null || true

# Pin outbound (user: main-5-out)
wget -qO- --timeout=5 --method=PUT --body-data="{\"name\":\"$OUT\"}" \
	--header='Content-Type: application/json' "$API" >/dev/null 2>&1 || \
	curl -4 -sS -m 8 -X PUT -H 'Content-Type: application/json' \
		-d "{\"name\":\"$OUT\"}" "$API" >/dev/null 2>&1 || true

tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

echo "=== boot-stable VERIFY ==="
uptime
echo "sing-box=$(pidof sing-box | wc -l)"
nslookup instagram.com "$LAN" 2>/dev/null | grep -i Address | tail -3
nslookup instagram.com 127.0.0.42 2>/dev/null | grep -i Address | tail -3
IG=$(curl -4 -sS -m 15 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null || echo fail)
echo "ig=$IG"
wget -qO- --timeout=3 "$API" 2>/dev/null | grep -o '"now": *"[^"]*"' | head -1
nft list chain inet PodkopTable mangle 2>/dev/null | grep counter | head -2

logger -t tr-boot-stable "ig=$IG"
[ "$IG" = "200" ] && exit 0
exit 1