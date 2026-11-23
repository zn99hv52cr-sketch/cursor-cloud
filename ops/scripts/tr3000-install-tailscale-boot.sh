#!/bin/sh
# TR3000: wire post-boot tailscale fix (run once as root, idempotent).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

fetch() { curl -fsSL "$1" -o "$2" 2>/dev/null || wget -qO "$2" "$1"; }

fetch "$BASE/tr3000-tailscale-boot.sh" /usr/bin/tr3000-tailscale-boot.sh
fetch "$BASE/tr3000-tailnet-pin.sh" /usr/bin/tr3000-tailnet-pin.sh
chmod +x /usr/bin/tr3000-tailscale-boot.sh /usr/bin/tr3000-tailnet-pin.sh

cat > /etc/init.d/tailscale-after-tunnel << 'EOF'
#!/bin/sh /etc/rc.common
# Runs after S99podkop* (name sorts later): tunnel first, then tailscaled refresh.
START=99
STOP=10

boot() {
	( sleep 15; /usr/bin/tr3000-tailscale-boot.sh ) &
}

start() {
	/usr/bin/tr3000-tailscale-boot.sh
}
EOF
chmod +x /etc/init.d/tailscale-after-tunnel
/etc/init.d/tailscale-after-tunnel enable

# Old hook only ran pin at 40s, before podkop — replace with no-op boot.
if [ -f /etc/init.d/tailnet-pin ]; then
	cat > /etc/init.d/tailnet-pin << 'EOF'
#!/bin/sh /etc/rc.common
START=98
STOP=10
boot() { : ; }
start() { /usr/bin/tr3000-tailnet-pin.sh; }
EOF
	chmod +x /etc/init.d/tailnet-pin
fi

# RunSSH is handled inside tr3000-tailscale-boot.sh; drop duplicate boot.
if [ -x /etc/init.d/tailscale-no-ssh ]; then
	/etc/init.d/tailscale-no-ssh disable 2>/dev/null || true
fi

# Also after every tunnel up (podkop restart).
touch /usr/bin/podkop-tun-up
chmod +x /usr/bin/podkop-tun-up
grep -q 'tr3000-tailscale-boot' /usr/bin/podkop-tun-up || \
	echo '/usr/bin/tr3000-tailscale-boot.sh' >> /usr/bin/podkop-tun-up

echo "enabled:"
ls -l /etc/rc.d/S99tailscale-after-tunnel
echo "podkop-tun-up tail:"
tail -5 /usr/bin/podkop-tun-up