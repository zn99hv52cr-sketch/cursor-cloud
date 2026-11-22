#!/bin/sh
# TR3000, run as root from LAN. Undoes the direct-path experiment: tailscaled's
# control plane goes back through the tunnel, where it works on this ISP, and
# the watchdog that guards it is fixed so it can actually see the failure.
#
# Evidence this is based on: curl to controlplane.tailscale.com succeeds from
# the router, while tailscaled reports "Unable to connect to the Tailscale
# coordination server". The only difference between the two is the socket mark
# 0x80000, which an earlier version of the pin script sent straight to the WAN.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"
AGENT_TS_IP="100.66.76.102"

fetch() { curl -fsSL "$1?v=$(date +%s)" -o "$2" 2>/dev/null || wget -qO "$2" "$1"; }

echo "=== 0) what the daemon logged during the last restart ==="
grep -iE 'tailscaled|control|derp|map' /tmp/ts-raw.log 2>/dev/null \
	| grep -viE 'crond|cron\.err' | tail -25 || echo "(no /tmp/ts-raw.log)"

echo
echo "=== 1) is the control plane inside the tunnel's subnet list? ==="
echo "controlplane 192.200.0.0/24 in podkop_subnets: $(nft list set inet PodkopTable podkop_subnets 2>/dev/null | grep -c '192.200')"
echo "tailscale bypass rules present now: $(nft list table inet PodkopTable 2>/dev/null | grep -c '0x00080000')"
echo "tailscale-direct.conf present: $([ -f /etc/dnsmasq.d/tailscale-direct.conf ] && echo yes || echo no)"

echo
echo "=== 2) install the corrected pin and watchdog ==="
for s in tr3000-tailnet-pin.sh tr3000-tailscale-watchdog.sh; do
	fetch "$BASE/$s" "/usr/bin/$s" || { echo "FETCH FAILED: $s"; exit 1; }
	chmod +x "/usr/bin/$s"
done
/usr/bin/tr3000-tailnet-pin.sh
tail -6 /tmp/tailnet-pin.log
echo "bypass rules after cleanup: $(nft list table inet PodkopTable 2>/dev/null | grep -c '0x00080000')"

echo
echo "=== 3) tunnel first, then the daemon ==="
pidof sing-box >/dev/null 2>&1 || { /usr/bin/podkop start >/dev/null 2>&1; sleep 20; }
[ "$(ip route show table podkop | wc -l)" -lt 3 ] && /usr/bin/podkop-restore-table.sh
echo "sing-box pid: $(pidof sing-box)  podkop routes: $(ip route show table podkop | wc -l)"
/etc/init.d/tailscale restart >/dev/null 2>&1
sleep 35
/usr/bin/tr3000-tailnet-pin.sh
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null

echo
echo "=== 4) did the control plane come back? ==="
tailscale status --json 2>/dev/null | sed -n '/"Health"/,+5p' | head -7
echo "-- peers seen online: $(tailscale status --json 2>/dev/null | grep -c '"Online": *true')"
tailscale status 2>/dev/null | grep -iE 'cursor-cloud|andrei|wr3000p'

echo
echo "=== 5) can the router reach the agent? ==="
tailscale ping -c 3 "$AGENT_TS_IP" 2>&1 | tail -3
curl -sS -m 8 -o /dev/null -w "router->agent tcp 9999: http=%{http_code}\n" "http://$AGENT_TS_IP:9999/" 2>&1 | tail -1

echo
echo "=== 6) watchdog is armed and can see this failure ==="
grep -c "hasn't received a network map" /usr/bin/tr3000-tailscale-watchdog.sh
grep -E 'tailnet-pin|watchdog' /etc/crontabs/root

echo
echo "=== 7) blocked sites ==="
echo "youtube=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null)" \
     "instagram=$(curl -4 -sS -m12 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)" \
     "telegram=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://web.telegram.org/ 2>/dev/null)"
echo "=== DONE ==="
