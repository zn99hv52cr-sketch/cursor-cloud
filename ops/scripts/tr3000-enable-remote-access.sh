#!/bin/sh
# Run once on TR3000 from LAN (ssh root@192.168.2.1 OR LuCI Terminal).
# Adds: Tailscale Serve (HTTPS LuCI), SSH on tailscale IP, then media fix.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

TS_IP=$(tailscale ip -4 2>/dev/null | head -1)
[ -n "$TS_IP" ] || { echo "no tailscale ip"; exit 1; }

# LuCI over HTTPS on your tailscale hostname (from phone/lte with Tailscale on)
tailscale serve reset 2>/dev/null || true
tailscale serve --bg --https=443 http://127.0.0.1:80
tailscale serve status || true

# uhttpd also listen on tailscale (plain HTTP if serve fails)
uci -q get uhttpd.main.listen_http >/dev/null || exit 0
if ! uci get uhttpd.main.listen_http | grep -q "$TS_IP"; then
  uci add_list uhttpd.main.listen_http="[::]:80"
  uci add_list uhttpd.main.listen_http="$TS_IP:80"
  uci commit uhttpd
  /etc/init.d/uhttpd restart
fi

# dropbear: SSH on tailscale + LAN (not only tailscale ssh policy)
if [ -f /etc/config/dropbear ]; then
  grep -q "$TS_IP" /etc/config/dropbear 2>/dev/null || {
    uci add dropbear dropbear
    uci set dropbear.@dropbear[-1].Interface='tailscale0'
    uci set dropbear.@dropbear[-1].Port='22'
    uci set dropbear.@dropbear[-1].PasswordAuth='on'
    uci set dropbear.@dropbear[-1].RootPasswordAuth='on'
    uci commit dropbear
    /etc/init.d/dropbear restart
  }
fi

echo "Remote: https://$(tailscale status --json 2>/dev/null | grep -o '\"DNSName\":\"[^\"]*' | head -1 | cut -d: -f2 | tr -d '\"' || echo cudy-tr3000)/"
echo "Or: http://$TS_IP/ (LuCI)  ssh root@$TS_IP"

# Apply TG/IG fix (same as tr3000-fix-instagram.sh)
if [ -x /mnt/usb/backups/../ops/scripts/tr3000-fix-instagram.sh ] 2>/dev/null; then
  sh /mnt/usb/backups/../ops/scripts/tr3000-fix-instagram.sh
elif [ -f /tmp/tr3000-fix-instagram.sh ]; then
  sh /tmp/tr3000-fix-instagram.sh
else
  /usr/bin/podkop-tun-up 2>/dev/null || true
  wget -qO- --timeout=5 --method=PUT --header='Content-Type: application/json' \
    --body-data='{"name":"main-1-out"}' http://127.0.0.1:9090/proxies/main-out 2>/dev/null || true
fi