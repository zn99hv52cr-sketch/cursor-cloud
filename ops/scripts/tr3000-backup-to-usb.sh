#!/bin/sh
# TR3000: snapshot the WORKING config straight onto the router's USB stick.
# Run ON the router as root. Output:
#   /mnt/usb/backups/archive/tr3000-WORKING-<stamp>/        (readable tree)
#   /mnt/usb/backups/archive/tr3000-WORKING-<stamp>.tar.gz  (single file)
#   /mnt/usb/backups/CURRENT-WORKING.txt                    (pointer + health)
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ -x /etc/init.d/usb-data-mount ] && /etc/init.d/usb-data-mount start
sleep 1

USB_ROOT="/mnt/usb/backups"
[ -d "$USB_ROOT" ] || { echo "ERROR: $USB_ROOT not mounted"; ls -la /mnt/usb 2>/dev/null; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
DIR="$USB_ROOT/archive/tr3000-WORKING-$STAMP"
mkdir -p "$DIR/uci" "$DIR/usr-bin" "$DIR/sysctl.d" "$DIR/dnsmasq.d" "$DIR/live"

save() { f="$1"; shift; "$@" >"$DIR/$f" 2>&1 || echo "(failed)" >"$DIR/$f"; }

# --- UCI ---
save uci/all.txt uci show
for s in podkop network firewall dhcp dropbear system wireless tailscale; do
	uci export "$s" >"$DIR/uci/$s.uci" 2>/dev/null || true
done
cp -a /etc/config "$DIR/etc-config" 2>/dev/null || true

# --- sing-box + podkop runtime ---
cp /etc/sing-box/config.json "$DIR/sing-box-config.json" 2>/dev/null || true
[ -d /tmp/sing-box/rulesets ] && cp -a /tmp/sing-box/rulesets "$DIR/sing-box-rulesets" 2>/dev/null || true

# --- custom scripts that keep blocked sites alive ---
for f in /usr/bin/podkop-tun-up /usr/bin/podkop-restore-mangle.sh \
	/usr/bin/podkop-restore-table.sh /usr/bin/podkop-guard.sh \
	/usr/bin/podkop-tg-pick.sh /usr/bin/tr3000-boot-stable.sh \
	/usr/bin/tr3000-wan-recover /usr/bin/tr3000-singbox-route-fix.sh; do
	[ -f "$f" ] && cp "$f" "$DIR/usr-bin/" 2>/dev/null || true
done
cp /etc/sysctl.d/99-*.conf "$DIR/sysctl.d/" 2>/dev/null || true
cp /etc/dnsmasq.d/*.conf "$DIR/dnsmasq.d/" 2>/dev/null || true
cp /etc/crontabs/root "$DIR/crontab-root" 2>/dev/null || true
cp /etc/dropbear/authorized_keys "$DIR/dropbear-authorized_keys" 2>/dev/null || true
cp /tmp/dhcp.leases "$DIR/dhcp.leases" 2>/dev/null || true

# --- live state (so a future restore can be compared against a known-good run) ---
save live/nft-ruleset.txt nft list ruleset
save live/ip-rule.txt ip rule
save live/ip-route-main.txt ip route
save live/ip-route-podkop.txt sh -c 'ip route show table podkop'
save live/netstat.txt sh -c 'pidof sing-box; netstat -lnpt 2>/dev/null | grep -E ":53|:2222|:1602|:9090"'
save live/main-out.txt sh -c 'wget -qO- --timeout=4 http://192.168.2.1:9090/proxies/main-out 2>/dev/null | head -c 2000'
save live/dns.txt sh -c 'for d in instagram.com youtube.com t.me web.telegram.org st.hdrezka.ac; do echo "== $d"; nslookup "$d" 192.168.2.1 2>&1 | grep -i Address; done'
save live/logread-tail.txt sh -c 'logread | tail -300'

YT=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null || echo fail)
IG=$(curl -4 -sS -m12 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null || echo fail)
TG=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://web.telegram.org/ 2>/dev/null || echo fail)
NOW=$(wget -qO- --timeout=4 http://192.168.2.1:9090/proxies/main-out 2>/dev/null | grep -o '"now":"[^"]*"' | head -1)

cat >"$DIR/HEALTH.txt" << EOF
TR3000 snapshot $STAMP (router local time: $(date))
uptime: $(uptime)
sing-box pid: $(pidof sing-box)
node: $NOW
youtube=$YT instagram=$IG telegram=$TG
podkop table rows: $(ip route show table podkop | wc -l)
EOF

cat >"$DIR/RESTORE.txt" << 'EOF'
Restore this snapshot on TR3000 (run as root, from LAN or ssh -p 2222):

  D=/mnt/usb/backups/archive/tr3000-WORKING-<stamp>
  uci import podkop < "$D/uci/podkop.uci" && uci commit podkop
  uci import dhcp   < "$D/uci/dhcp.uci"   && uci commit dhcp
  cp "$D/usr-bin/"* /usr/bin/ && chmod +x /usr/bin/podkop-* /usr/bin/tr3000-*
  cp "$D/dnsmasq.d/"*.conf /etc/dnsmasq.d/ 2>/dev/null
  cp "$D/sysctl.d/"*.conf /etc/sysctl.d/ 2>/dev/null
  cp "$D/crontab-root" /etc/crontabs/root && /etc/init.d/cron restart
  /etc/init.d/dnsmasq restart
  /etc/init.d/podkop restart; sleep 25
  /usr/bin/podkop-tun-up; /usr/bin/podkop-restore-mangle.sh; /usr/bin/podkop-restore-table.sh
  /usr/bin/podkop-guard.sh

Rules that must survive any restore:
  * podkop.main outbound = KotiKey nodes ONLY. No FI VPS / vpn2 proxy_string.
  * NO podkop.hdrezka_direct section: it makes podkop emit a DNS rule for an
    undeclared ruleset and sing-box crash-loops. HDrezka stays direct through
    /etc/dnsmasq.d/hdrezka-direct.conf.
  * Table podkop needs "default dev sbtun" + 198.18.0.0/15, else blocked sites
    resolve to fakeip and then time out.
  * Do NOT run tailscale restart / tailscale up --ssh. Agent uses dropbear :2222.
EOF

tar -czf "$DIR.tar.gz" -C "$USB_ROOT/archive" "tr3000-WORKING-$STAMP"

cat >"$USB_ROOT/CURRENT-WORKING.txt" << EOF
Latest known-good TR3000 snapshot: archive/tr3000-WORKING-$STAMP
Tarball: archive/tr3000-WORKING-$STAMP.tar.gz
Taken: $(date)
Health: youtube=$YT instagram=$IG telegram=$TG node=$NOW
EOF

sync
echo "BACKUP_OK $DIR"
ls -la "$DIR.tar.gz"
cat "$DIR/HEALTH.txt"
df -h /mnt/usb | tail -1
