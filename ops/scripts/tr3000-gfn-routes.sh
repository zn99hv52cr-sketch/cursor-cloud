#!/bin/sh
# TR3000 (OpenWrt + podkop): GeForce NOW → VPN (админка + выбор сервера + nvidiagrid).
# Запуск на роутере: sh /usr/bin/tr3000-gfn-routes.sh
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LAN="$(uci get network.lan.ipaddr 2>/dev/null | sed 's|/.*||' || echo 192.168.2.1)"

DOMAINS="
geforcenow.com
play.geforcenow.com
status.geforcenow.com
gfn.nvidia.com
nvidia.com
login.nvidia.com
accounts.nvidia.com
api-prod.nvidia.com
static-login.nvidia.com
events.gfe.nvidia.com
gtc.nvidia.com
nvidiagrid.net
cloudmatchbeta.nvidiagrid.net
prod.cloudmatchbeta.nvidiagrid.net
services.gfe.nvidia.com
geforce.com
"

# EU-узлы GFN (Frankfurt и др.) — иначе после match трафик на VM-IP уйдёт в WAN.
SUBNETS="
77.111.248.0/22
77.111.249.0/24
"

for d in $DOMAINS; do
	uci get podkop.main.user_domains 2>/dev/null | tr ' ' '\n' | grep -Fx "$d" >/dev/null && continue
	uci add_list podkop.main.user_domains="$d"
done

for c in $SUBNETS; do
	uci get podkop.main.user_subnets 2>/dev/null | tr ' ' '\n' | grep -Fx "$c" >/dev/null && continue
	uci add_list podkop.main.user_subnets="$c"
done

uci commit podkop
/usr/bin/podkop list_update >/tmp/tr-gfn-list.log 2>&1 || /etc/init.d/podkop restart
sleep 3
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up 2>/dev/null || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh 2>/dev/null || true

echo "=== GFN DNS (ожидаем 198.18.x при podkop fakeip) ==="
for d in play.geforcenow.com prod.cloudmatchbeta.nvidiagrid.net login.nvidia.com; do
	printf '%s → ' "$d"
	nslookup "$d" "$LAN" 2>/dev/null | awk '/^Address: / && $2 !~ /^'"$LAN"'$/ {print $2; exit}'
done
echo "=== user_domains (gfn/nvidia) ==="
uci get podkop.main.user_domains 2>/dev/null | tr ' ' '\n' | grep -iE 'geforce|nvidia|nvidiagrid' | sort -u
echo "=== user_subnets (gfn) ==="
uci get podkop.main.user_subnets 2>/dev/null | tr ' ' '\n' | grep 77.111 || true
logger -t tr-gfn-routes done