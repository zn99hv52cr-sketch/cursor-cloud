#!/bin/sh
# WR3000P: fix LAN phone/TV — empty mangle + 198.20 fakeip, dnsmasq, pin main-1-out.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
API="${PODKOP_API:-http://127.0.0.1:9090/proxies/main-out}"
LAN="$(uci get network.lan.ipaddr 2>/dev/null | sed 's|/.*||' || echo 192.168.1.1)"
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

logger -t wr-lan-fix "start"

curl -fsSL "$BASE/wr3000p-podkop-tun-up.sh" -o /usr/bin/podkop-tun-up && chmod +x /usr/bin/podkop-tun-up
curl -fsSL "$BASE/wr3000p-podkop-restore-mangle.sh" -o /usr/bin/podkop-restore-mangle.sh && chmod +x /usr/bin/podkop-restore-mangle.sh
[ -x /usr/bin/wr3000p-restore-kotikey.sh ] && /usr/bin/wr3000p-restore-kotikey.sh 2>/dev/null || true

uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server='127.0.0.42#53'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci -q delete dhcp.lan.dhcp_option 2>/dev/null || true
uci add_list dhcp.lan.dhcp_option="6,$LAN"
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 2

if ! pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop start >/tmp/wr-podkop.log 2>&1 || true
	sleep 8
else
	/usr/bin/podkop list_update >/tmp/wr-podkop.log 2>&1 || true
	sleep 2
fi
/usr/bin/podkop-tun-up 2>/dev/null || true
/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
/usr/bin/wr3000p-podkop-route-fix.sh 2>/dev/null || true
killall -HUP dnsmasq 2>/dev/null || true

wget -qO- --timeout=5 --method=PUT --body-data='{"name":"main-1-out"}' \
	--header='Content-Type: application/json' "$API" >/dev/null 2>&1 || true
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

echo "=== WR LAN VERIFY ==="
pidof sing-box
nslookup instagram.com "$LAN" | tail -2
nslookup youtube.com 127.0.0.42 | tail -2
nft list chain inet PodkopTable mangle | grep -E '198.20|counter' | head -6
IG=$(curl -4 -m15 -o /dev/null -w '%{http_code}' https://www.instagram.com/)
YT=$(curl -4 -m15 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204)
TG=$(curl -4 -m15 -o /dev/null -w '%{http_code}' https://web.telegram.org/)
echo "router: ig=$IG yt=$YT tg=$TG"
wget -qO- --timeout=3 "$API" 2>/dev/null | grep -o '"now":"[^"]*"' | head -1
logger -t wr-lan-fix "ig=$IG yt=$YT"