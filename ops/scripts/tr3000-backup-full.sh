#!/bin/sh
# Full TR3000 config backup — run ON router (root). Creates /tmp/tr3000-backup-*.tar.gz
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
STAMP="$(date +%Y%m%d-%H%M%S)"
DIR="/tmp/tr3000-backup-$STAMP"
OUT="/tmp/tr3000-backup-$STAMP.tar.gz"
mkdir -p "$DIR"

backup() { f="$1"; shift; "$@" >"$DIR/$f" 2>&1 || echo "(failed $f)" >"$DIR/$f"; }

backup uci-show-all.txt uci show
for s in network firewall dhcp podkop dropbear tailscale; do
	backup "uci-export-$s.txt" uci export "$s"
done

cp -a /etc/config "$DIR/etc-config" 2>/dev/null || true
[ -d /tmp/sing-box ] && cp -a /tmp/sing-box "$DIR/sing-box" 2>/dev/null || true
[ -f /usr/bin/podkop-tun-up ] && cp /usr/bin/podkop-tun-up "$DIR/" 2>/dev/null || true
[ -f /usr/bin/podkop-restore-mangle.sh ] && cp /usr/bin/podkop-restore-mangle.sh "$DIR/" 2>/dev/null || true
[ -f /usr/bin/tr3000-wan-recover ] && cp /usr/bin/tr3000-wan-recover "$DIR/" 2>/dev/null || true
cp /etc/dropbear/authorized_keys "$DIR/dropbear-authorized_keys" 2>/dev/null || true
cp /etc/crontabs/root "$DIR/crontab-root" 2>/dev/null || true
cp /tmp/dhcp.leases "$DIR/dhcp.leases" 2>/dev/null || true

backup nft-ruleset.txt nft list ruleset
backup ip-rule.txt ip rule
backup ip-route-main.txt ip route
backup ip-route-podkop.txt sh -c 'ip route show table podkop 2>/dev/null || true'
backup ip-route-get-fakeip.txt sh -c 'ip route get 198.18.0.26 from 192.168.2.195 iif br-lan 2>/dev/null; ip route get 198.18.0.15 from 192.168.2.145 iif br-lan 2>/dev/null'
backup net-stat.txt sh -c 'pidof sing-box; netstat -lnpt 2>/dev/null | grep -E ":53|:2222|:1602"; tailscale status 2>/dev/null | head -20'
backup nslookup.txt sh -c 'nslookup instagram.com 127.0.0.42; nslookup st.hdrezka.ac 127.0.0.42'
backup logread-tail.txt sh -c 'logread | tail -400'

tar -czf "$OUT" -C /tmp "tr3000-backup-$STAMP"
echo "BACKUP_OK $OUT"
ls -la "$OUT"
echo "Copy to PC: scp root@192.168.2.1:$OUT ."