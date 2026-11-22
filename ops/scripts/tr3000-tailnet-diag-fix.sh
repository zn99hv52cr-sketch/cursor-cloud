#!/bin/sh
# TR3000: find out why inbound tailnet TCP to dropbear :2222 never answers, and
# fix it if the cause is the router's own firewall.
#
# Splits the two possible causes apart:
#   * packets arrive on tailscale0 -> the router's filter drops them (fixable here)
#   * packets never arrive         -> the tailnet ACL drops them before delivery
#     (fixable only in the Tailscale admin console)
# Run as root from LAN. Safe to re-run.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
AGENT_TS_IP="100.66.76.102"
WINDOW=25

echo "=== 1) is the agent node even in the router's netmap? ==="
tailscale status 2>/dev/null | grep -iE 'cursor-cloud|cursor-agent' || echo "AGENT NODE NOT IN NETMAP"

echo
echo "=== 2) tailscale0 and its firewall zone ==="
ip -br addr show tailscale0 2>&1
echo "-- uci zones:"
for i in 0 1 2 3 4 5 6; do
	n=$(uci -q get "firewall.@zone[$i].name") || continue
	echo "zone[$i] name=$n net='$(uci -q get firewall.@zone[$i].network)' dev='$(uci -q get firewall.@zone[$i].device)' input=$(uci -q get firewall.@zone[$i].input)"
done
echo "-- uci rules mentioning 2222 or tailscale:"
uci show firewall 2>/dev/null | grep -iE '2222|tailscale' || echo "(none)"
echo "-- does fw4 know tailscale0?"
nft list ruleset 2>/dev/null | grep -c 'tailscale0'
echo "-- fw4 input policy:"
nft list chain inet fw4 input 2>/dev/null | head -12

echo
echo "=== 3) counter: do the agent's SYNs reach this box at all? ==="
nft delete chain inet fw4 tsdiag 2>/dev/null
nft add chain inet fw4 tsdiag '{ type filter hook input priority -150 ; policy accept; }' 2>/dev/null
nft add rule inet fw4 tsdiag iifname "tailscale0" tcp dport 2222 counter 2>/dev/null
nft add rule inet fw4 tsdiag ip saddr "$AGENT_TS_IP" counter 2>/dev/null

echo "=== 4) meanwhile: accept :2222 from tailscale0 right now ==="
nft insert rule inet fw4 input iifname "tailscale0" tcp dport 2222 counter accept 2>/dev/null \
	&& echo "live accept rule inserted"

echo "=== 5) and make that survive a firewall reload ==="
if ! uci show firewall 2>/dev/null | grep -q 'Allow-SSH-2222-tailscale0'; then
	uci add firewall rule >/dev/null
	uci set firewall.@rule[-1].name='Allow-SSH-2222-tailscale0'
	uci set firewall.@rule[-1].src='*'
	uci set firewall.@rule[-1].device='tailscale0'
	uci set firewall.@rule[-1].proto='tcp'
	uci set firewall.@rule[-1].dest_port='2222'
	uci set firewall.@rule[-1].target='ACCEPT'
	uci commit firewall
	echo "uci rule added"
fi

echo
echo "=== 6) reverse direction: can this router open TCP to the agent? ==="
tailscale ping -c 2 "$AGENT_TS_IP" 2>&1 | tail -2
curl -sS -m 8 -o /dev/null -w "router->agent tcp 9999: http=%{http_code} connect=%{time_connect}s\n" \
	"http://$AGENT_TS_IP:9999/" 2>&1 | tail -1

echo
echo "=== 7) watching for $WINDOW s while the agent retries ==="
/etc/init.d/firewall reload >/dev/null 2>&1
nft add rule inet fw4 input iifname "tailscale0" tcp dport 2222 counter accept 2>/dev/null
sleep "$WINDOW"

echo "-- tsdiag counters (nonzero = packets really arrive):"
nft list chain inet fw4 tsdiag 2>/dev/null
echo "-- sockets on 2222:"
netstat -an 2>/dev/null | grep ':2222' | head -10
echo "-- dropbear/tailscale log tail:"
logread 2>/dev/null | grep -iE 'dropbear|tailscal' | tail -15

echo
echo "=== 8) verdict helper ==="
echo "counters above all zero  -> tailnet ACL blocks tag:cursor-cloud, fix in admin console"
echo "counters nonzero         -> firewall was the cause, agent should be in now"
echo "=== DONE ==="
