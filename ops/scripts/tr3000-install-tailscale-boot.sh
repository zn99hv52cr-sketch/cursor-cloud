#!/bin/sh
# TR3000: tailscale-first boot wiring (idempotent). tailscaled=S80, this=S81,
# podkop=S99 — remote access never waits for the VPN.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

fetch() { curl -fsSL "$1" -o "$2" 2>/dev/null || wget -qO "$2" "$1"; }

fetch "$BASE/tr3000-tailscale-boot.sh" /usr/bin/tr3000-tailscale-boot.sh
fetch "$BASE/tr3000-tailnet-pin.sh" /usr/bin/tr3000-tailnet-pin.sh
chmod +x /usr/bin/tr3000-tailscale-boot.sh /usr/bin/tr3000-tailnet-pin.sh

cat > /etc/init.d/tailscale-first << 'EOF'
#!/bin/sh /etc/rc.common
START=81
STOP=10
boot() { ( sleep 5; /usr/bin/tr3000-tailscale-boot.sh ) & }
start() { /usr/bin/tr3000-tailscale-boot.sh; }
EOF
chmod +x /etc/init.d/tailscale-first
/etc/init.d/tailscale-first enable

[ -x /etc/init.d/tailscale-after-tunnel ] && /etc/init.d/tailscale-after-tunnel disable 2>/dev/null

cat > /etc/init.d/tailnet-pin << 'EOF'
#!/bin/sh /etc/rc.common
START=98
STOP=10
boot() { : ; }
start() { /usr/bin/tr3000-tailnet-pin.sh; }
EOF
chmod +x /etc/init.d/tailnet-pin

if [ -x /etc/init.d/tailscale-no-ssh ]; then
	/etc/init.d/tailscale-no-ssh disable 2>/dev/null || true
fi

[ -f /usr/bin/podkop-tun-up ] && sed -i '/tr3000-tailscale-boot/d' /usr/bin/podkop-tun-up
touch /usr/bin/podkop-tun-up
chmod +x /usr/bin/podkop-tun-up
grep -q 'tr3000-tailnet-pin' /usr/bin/podkop-tun-up || \
	echo '/usr/bin/tr3000-tailnet-pin.sh' >> /usr/bin/podkop-tun-up

echo "enabled:"
ls -l /etc/rc.d/S81tailscale-first 2>/dev/null
echo "removed S99 tailscale-after-tunnel:"
ls /etc/rc.d/S99tailscale-after-tunnel 2>&1 || echo "(gone)"