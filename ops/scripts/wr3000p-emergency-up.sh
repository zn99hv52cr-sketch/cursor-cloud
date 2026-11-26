#!/bin/sh
# WR3000P: when LAN is dead — restore tun sbtun, routes, mangle, pick KotiKey node.
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOCK=/var/lock/wr-emergency.lock
mkdir -p /var/lock
exec 8>"$LOCK"
flock -x 8 || exit 0

killall podkop-tg-pick.sh 2>/dev/null || true
rm -f /var/lock/sing-box-config.lock

[ -s /etc/sing-box/config.json ] || /usr/bin/wr3000p-restore-kotikey.sh 2>/dev/null || true

CFG=/etc/sing-box/config.json
jq "
  (.inbounds[] | select(.tag==\"tproxy-in\")) = {
    \"type\":\"tun\",\"tag\":\"tproxy-in\",\"interface_name\":\"sbtun\",
    \"address\":[\"172.31.0.1/30\"],\"mtu\":1400,\"auto_route\":false,
    \"strict_route\":false,\"stack\":\"mixed\"
  }
  | (.outbounds[] | select(.type==\"vless\" and (.tls.reality.enabled? == true))) |= del(.transport)
  | (.outbounds[] | select(.tag==\"main-out\" and .type==\"selector\")) |= (
      .outbounds |= map(select(. != \"main-urltest-out\"))
    )
" "$CFG" > /tmp/sb-em.json 2>/dev/null || exit 1
sing-box check -c /tmp/sb-em.json || exit 1
cp /tmp/sb-em.json "$CFG"
cp "$CFG" /etc/sing-box/config.json.ok
/etc/init.d/sing-box restart
i=0
while ! ip link show sbtun >/dev/null 2>&1 && [ "$i" -lt 45 ]; do sleep 1; i=$((i + 1)); done
ip link set sbtun mtu 1400 2>/dev/null

/usr/bin/podkop-yt-routes 2>/dev/null || true
/usr/bin/wr3000p-podkop-route-fix.sh
/usr/bin/podkop-restore-mangle.sh
nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-out || \
	nft insert rule inet fw4 forward iifname br-lan oifname sbtun accept comment sbtun-out
nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-in || \
	nft insert rule inet fw4 forward iifname sbtun oifname br-lan accept comment sbtun-in

flock -n /var/lock/podkop-tg-pick.lock /usr/bin/podkop-tg-pick.sh || true
logger -t wr-emergency "done routes=$(ip route | grep -c 'dev sbtun')"