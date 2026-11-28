#!/bin/sh
# TR3000 emergency: nothing loads — bring podkop/DNS/mangle/2222 back.
# Run from LAN Termius: curl ... | sh
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

logger -t tr-emergency "start"
killall -9 uci 2>/dev/null || true

# Ensure restore-mangle on disk
curl -fsSL "$BASE/tr3000-podkop-restore-mangle.sh" -o /usr/bin/podkop-restore-mangle.sh && chmod +x /usr/bin/podkop-restore-mangle.sh
curl -fsSL "$BASE/tr3000-wan-recover.sh" -o /usr/bin/tr3000-wan-recover && chmod +x /usr/bin/tr3000-wan-recover
grep -q podkop-restore-mangle /usr/bin/podkop-tun-up 2>/dev/null || echo '/usr/bin/podkop-restore-mangle.sh' >> /usr/bin/podkop-tun-up

# Soft start: don't hang on full procd restart if possible
if ! pidof sing-box >/dev/null 2>&1; then
	/usr/bin/podkop start >/tmp/podkop-emergency.log 2>&1 || true
	sleep 10
fi
if ! pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/sing-box start 2>/dev/null || true
	sleep 5
fi

/usr/bin/podkop-tun-up >/tmp/tun-emergency.log 2>&1 || true
/usr/bin/podkop-restore-mangle.sh || true

# DNS
uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
uci add_list dhcp.@dnsmasq[0].server='127.0.0.42#53'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 2
killall -HUP dnsmasq 2>/dev/null || true

# dropbear 2222 for agent (no tailscale restart)
AGENT_PUB='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag'
grep -qF "$AGENT_PUB" /etc/dropbear/authorized_keys 2>/dev/null || echo "$AGENT_PUB" >> /etc/dropbear/authorized_keys
if ! uci -q get dropbear.alt.Port >/dev/null 2>&1; then
	uci set dropbear.alt=dropbear
	uci set dropbear.alt.enable='1'
	uci set dropbear.alt.Port='2222'
	uci set dropbear.alt.PasswordAuth='on'
	uci set dropbear.alt.RootPasswordAuth='on'
	uci set dropbear.alt.Interface=''
	uci commit dropbear
	/etc/init.d/dropbear restart
fi
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

# VERIFY
echo "=== VERIFY ==="
echo "sing-box=$(pidof sing-box | wc -l)"
nslookup instagram.com 127.0.0.42 2>/dev/null | grep Address | tail -2
nslookup chatgpt.com 127.0.0.42 2>/dev/null | grep Address | tail -2
nft list chain inet PodkopTable mangle 2>/dev/null | grep -c counter || echo 0
ip route get 198.18.0.15 from 192.168.2.145 iif br-lan 2>/dev/null | head -1
netstat -lnpt 2>/dev/null | grep ':2222' || true
logger -t tr-emergency "done"