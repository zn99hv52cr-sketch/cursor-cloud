#!/bin/sh
# One-time on TR3000 from LAN: LuCI → System → Terminal (or ssh root@192.168.2.1).
# Makes Cloud Agent reach dropbear :2222 over Tailscale; disables RunSSH on :22.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
AGENT_PUB='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag'

echo "=== 1) agent key in dropbear ==="
mkdir -p /etc/dropbear
grep -qF "$AGENT_PUB" /etc/dropbear/authorized_keys 2>/dev/null || echo "$AGENT_PUB" >> /etc/dropbear/authorized_keys

echo "=== 2) dropbear :2222 on all interfaces (incl. tailscale0) ==="
if ! uci -q get dropbear.alt.Port >/dev/null 2>&1; then
	uci set dropbear.alt=dropbear
	uci set dropbear.alt.Interface=''
	uci set dropbear.alt.enable='1'
	uci set dropbear.alt.Port='2222'
	uci set dropbear.alt.PasswordAuth='on'
	uci set dropbear.alt.RootPasswordAuth='on'
	uci commit dropbear
else
	uci set dropbear.alt.Interface=''
	uci set dropbear.alt.Port='2222'
	uci set dropbear.alt.enable='1'
	uci commit dropbear
fi
/etc/init.d/dropbear restart
sleep 1
netstat -lnpt 2>/dev/null | grep ':2222' || ss -lnpt | grep ':2222'

echo "=== 3) firewall: SSH 2222 from tailscale ==="
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

echo "=== 4) tailscale: RunSSH off (no full restart — keeps podkop/sing-box up) ==="
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true
tailscale set --advertise-routes=192.168.2.0/24,192.168.1.254/32 \
	--accept-dns=false --hostname=cudy-tr3000 2>/dev/null || true

if [ ! -x /etc/init.d/tailscale-no-ssh ]; then
	cat > /etc/init.d/tailscale-no-ssh << 'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() { sleep 25; tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null; }
start() { boot; }
EOF
	chmod +x /etc/init.d/tailscale-no-ssh
	/etc/init.d/tailscale-no-ssh enable
fi

echo "=== 5) apply podkop boot fix if present ==="
[ -x /usr/bin/tr3000-wan-recover ] && /usr/bin/tr3000-wan-recover manual || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh || true

echo "=== done ==="
echo "From phone Tailscale: ssh -p 2222 root@100.81.160.52 (should NOT use port 22)"
tailscale status | head -5