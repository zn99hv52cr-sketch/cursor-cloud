#!/bin/sh
# One-shot on TR (Termius 192.168.2.1): permanent Cloud Agent SSH on Tailscale :2222.
# Does NOT restart tailscale (no vpn/ssh outage).
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
AGENT_PUB='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag'

logger -t tr-agent-ssh "start"

# 1) Agent key
grep -qF "$AGENT_PUB" /etc/dropbear/authorized_keys 2>/dev/null || echo "$AGENT_PUB" >> /etc/dropbear/authorized_keys

# 2) dropbear :2222 all interfaces (same as WR)
if ! uci -q get dropbear.alt.Port >/dev/null 2>&1; then
	uci add dropbear dropbear
	uci rename dropbear.@dropbear[-1]='alt'
fi
uci set dropbear.alt=dropbear
uci set dropbear.alt.enable='1'
uci set dropbear.alt.Port='2222'
uci set dropbear.alt.Interface=''
uci set dropbear.alt.PasswordAuth='on'
uci set dropbear.alt.RootPasswordAuth='on'
uci commit dropbear
/etc/init.d/dropbear restart

# 3) Firewall tailscale -> 2222
if ! uci show firewall 2>/dev/null | grep -q 'Allow-SSH-2222-Tailscale'; then
	uci add firewall rule
	uci set firewall.@rule[-1].name='Allow-SSH-2222-Tailscale'
	uci set firewall.@rule[-1].src='tailscale'
	uci set firewall.@rule[-1].dest='*'
	uci set firewall.@rule[-1].proto='tcp'
	uci set firewall.@rule[-1].dest_port='2222'
	uci set firewall.@rule[-1].target='ACCEPT'
	uci commit firewall
	/etc/init.d/firewall reload
fi

# 4) RunSSH off on :22 (agent uses 2222 only). NO tailscale restart.
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true

# 5) After boot: keep RunSSH off
if [ ! -x /etc/init.d/tailscale-no-ssh ]; then
	cat > /etc/init.d/tailscale-no-ssh << 'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() { sleep 30; tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null; }
start() { boot; }
EOF
	chmod +x /etc/init.d/tailscale-no-ssh
	/etc/init.d/tailscale-no-ssh enable
fi

echo "=== AGENT ACCESS OK ==="
netstat -lnpt 2>/dev/null | grep ':2222' || true
echo "Cloud agent: ssh -p 2222 root@100.81.160.52"
echo "Tailscale Admin ACL still needed if you use tailscale ssh :22 (see ops/tr3000-agent-access.md)"
logger -t tr-agent-ssh "done"