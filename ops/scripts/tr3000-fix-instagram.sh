#!/bin/sh
# Run ON TR3000 (ssh root@192.168.2.1). Locks IG/YT/TG to main-1..4, no urltest in selector.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
API=http://192.168.2.1:9090/proxies/main-out
LINKS=/mnt/usb/backups/koty-k-kotikey/urltest-preferred.links

# Podkop: urltest group exists but NOT in selector (no auto node hop)
if grep -q 'outbound_tags,$urltest_tag' /usr/bin/podkop 2>/dev/null; then
  sed -i 's|selector_outbounds="$(comma_string_to_json_array "$outbound_tags,$urltest_tag")"|selector_outbounds="$(comma_string_to_json_array "$outbound_tags")"|' /usr/bin/podkop
fi

# Only first 4 KotiKey nodes (main-1..4); 5–8 often break TG/IG video
if [ -f "$LINKS" ]; then
  uci -q delete podkop.main.urltest_proxy_links
  n=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue;; esac
    uci add_list podkop.main.urltest_proxy_links="$line"
    n=$((n + 1))
    [ "$n" -ge 4 ] && break
  done < "$LINKS"
fi
uci set podkop.main.proxy_config_type=urltest
uci set podkop.main.urltest_check_interval=30m
uci set podkop.main.urltest_tolerance=100
for d in scontent.cdninstagram.com igcdn.com instagram.com cdninstagram.com fbcdn.net \
  upload.telegram.org cdn.telegram.org; do
  uci add_list podkop.main.user_domains="$d" 2>/dev/null || true
done
uci commit podkop

cat > /usr/bin/podkop-tg-pick.sh << 'PICK'
#!/bin/sh
PATH=/usr/sbin:/usr/bin:/sbin:/bin
API=http://192.168.2.1:9090/proxies/main-out
ok() {
  yt=$(curl -4 -sS -m 8 -o /dev/null -w "%{http_code}" https://www.youtube.com/generate_204 2>/dev/null) || yt=0
  tg=$(curl -4 -sS -m 8 -o /dev/null -w "%{http_code}" https://web.telegram.org/ 2>/dev/null) || tg=0
  ig=$(curl -4 -sS -m 12 -o /dev/null -w "%{http_code}" https://www.instagram.com/ 2>/dev/null) || ig=0
  [ "$yt" = "204" ] && [ "$tg" = "200" ] && [ "$ig" = "200" ]
}
pin() {
  wget -qO- --timeout=4 --method=PUT --body-data="{\"name\":\"$1\"}" \
    --header="Content-Type: application/json" "$API" >/dev/null 2>&1 || true
}
pin "main-1-out"
for i in 1 2 3; do sleep 2; ok && exit 0; done
for n in 2 3 4; do pin "main-${n}-out"; sleep 2; ok && exit 0; done
pin "main-1-out"
PICK
chmod +x /usr/bin/podkop-tg-pick.sh

cat > /etc/sysctl.d/99-vpn-bulk.conf << 'SYS'
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 262144 4194304
net.ipv4.tcp_wmem=4096 131072 4194304
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
SYS
sysctl -p /etc/sysctl.d/99-vpn-bulk.conf 2>/dev/null || true

/etc/init.d/podkop restart
sleep 6
# After reboot, MSS + Meta/TG routes only apply via tun-up
/usr/bin/podkop-tun-up || true
sleep 3
/usr/bin/podkop-tun-up || true
rm -f /tmp/sing-box/cache.db
killall -HUP dnsmasq 2>/dev/null || true
/usr/bin/podkop-tg-pick.sh
wget -qO- --timeout=4 --method=PUT --body-data='{"name":"main-1-out"}' \
  --header='Content-Type: application/json' "$API" >/dev/null 2>&1 || true

# Every 2 min re-pin if something moved the node
grep -q 'tr3000-fix-instagram' /etc/crontabs/root 2>/dev/null || \
  echo '*/2 * * * * /usr/bin/podkop-tg-pick.sh # tr3000-fix-instagram' >> /etc/crontabs/root
/etc/init.d/cron restart 2>/dev/null || true

echo OK now=$(wget -qO- --timeout=3 "$API" 2>/dev/null | grep -o '"now":"[^"]*"' | head -1)