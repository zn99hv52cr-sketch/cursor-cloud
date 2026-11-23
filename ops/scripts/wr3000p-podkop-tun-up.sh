#!/bin/sh
# WR3000P: sbtun + FakeIP (198.20) + LAN routes from SharpVPN backup.
# KotiKey (urltest): do NOT patch VLESS with FI WebSocket — breaks Reality.
# Sharp FI WS (selector): legacy jq block in apply_sharp_jq.
CFG=/etc/sing-box/config.json
OK=/etc/sing-box/config.json.ok
LOCK=/var/lock/sing-box-config.lock
mkdir -p /var/lock /tmp/sing-box

exec 9>"$LOCK"
flock 9 || exit 1

PROXY_CFG="$(uci -q get podkop.main.proxy_config_type 2>/dev/null)"

restore_cfg() {
	if [ -s "$OK" ]; then
		cp -a "$OK" "$CFG"
		logger -t podkop-tun "restored config.json from .ok"
		return 0
	fi
	if [ -s /overlay/backups/sing-box-config.ok.json ]; then
		cp -a /overlay/backups/sing-box-config.ok.json "$CFG"
		logger -t podkop-tun "restored config.json from overlay backup"
		return 0
	fi
	logger -t podkop-tun "config empty — running podkop start to regenerate"
	/etc/init.d/podkop start >/tmp/podkop-guard.restart 2>&1 || true
	sleep 8
	[ -s "$CFG" ]
}

i=0
while [ ! -s "$CFG" ] && [ "$i" -lt 30 ]; do
	restore_cfg || true
	sleep 1
	i=$((i + 1))
done
if [ ! -s "$CFG" ]; then
	logger -t podkop-tun "FATAL: no valid sing-box config"
	exit 1
fi

apply_routes() {
	for r in \
		198.18.0.0/15 198.20.0.0/15 \
		5.28.192.0/18 91.105.192.0/23 91.108.4.0/22 91.108.8.0/22 \
		91.108.12.0/22 91.108.16.0/22 91.108.20.0/22 91.108.56.0/22 95.161.64.0/20 \
		149.154.160.0/20 185.76.151.0/24 \
		31.13.24.0/21 31.13.64.0/18 57.144.0.0/14 66.220.144.0/20 69.171.224.0/19 \
		129.134.0.0/17 157.240.0.0/16 173.252.64.0/18 179.60.192.0/22 185.60.216.0/22 \
		76.76.0.0/16 66.33.60.0/23 212.124.96.0/19 102.132.96.0/20 163.70.128.0/17 \
		142.250.0.0/15 172.217.0.0/16 172.253.0.0/16 216.58.192.0/19 216.239.32.0/19 \
		74.125.0.0/16 108.177.0.0/17 173.194.0.0/16 209.85.128.0/17 64.233.160.0/19 \
		66.102.0.0/20 130.211.0.0/16 192.178.0.0/15 66.249.80.0/20 72.14.192.0/18
	do
		ip route replace "$r" dev sbtun 2>/dev/null
	done
}

finish_hooks() {
	apply_routes
	/usr/bin/podkop-yt-routes 2>/dev/null || true
	/usr/bin/podkop-restore-mangle.sh 2>/dev/null || true
	/usr/bin/wr3000p-podkop-route-fix.sh 2>/dev/null || true
}

safe_install_cfg() {
	src="$1"
	[ -s "$src" ] || return 1
	jq empty "$src" 2>/dev/null || return 1
	sing-box check -c "$src" >/dev/null 2>&1 || return 1
	old=$(md5sum "$CFG" 2>/dev/null | awk '{print $1}')
	new=$(md5sum "$src" | awk '{print=$1}')
	if [ "$old" != "$new" ]; then
		cp -a "$src" "$CFG.tmp.$$" && mv "$CFG.tmp.$$" "$CFG"
		cp -a "$CFG" "$OK"
		logger -t podkop-tun "sing-box config updated (mode=$PROXY_CFG)"
		/etc/init.d/sing-box stop 2>/dev/null || killall sing-box 2>/dev/null
		rm -f /tmp/sing-box/cache.db-lock
		sleep 1
	else
		rm -f "$src"
	fi
	return 0
}

kotikey_jq='
(.inbounds[] | select(.tag=="tproxy-in")) = {
  "type":"tun","tag":"tproxy-in","interface_name":"sbtun",
  "address":["172.31.0.1/30"],"mtu":1400,"auto_route":false,
  "strict_route":false,"stack":"mixed"
}
|
(.experimental.cache_file.path) = "/tmp/sing-box/cache.db"
|
(.dns.servers[] | select(.tag=="fakeip-server") | .inet4_range) = "198.20.0.0/15"
|
(.route.rules) |= map(select(.protocol != "quic"))
|
.route.rules = [{"protocol":"quic","inbound":"tproxy-in","outbound":"block"}] + .route.rules
|
if any(.outbounds[]; .tag=="block") then . else .outbounds += [{"type":"block","tag":"block"}] end
|
if any(.outbounds[]; .tag=="direct-out") then . else .outbounds += [{"type":"direct","tag":"direct-out"}] end
|
(.outbounds[] | select(.type=="vless" and (.tls.reality.enabled? == true))) |= del(.transport)
|
(.outbounds[] | select(.tag=="main-out" and .type=="selector")) |= (
  .outbounds |= map(select(. != "main-urltest-out"))
)
'

sharp_jq='
(.inbounds[] | select(.tag=="tproxy-in")) = {
  "type":"tun","tag":"tproxy-in","interface_name":"sbtun",
  "address":["172.31.0.1/30"],"mtu":1400,"auto_route":false,
  "strict_route":false,"stack":"mixed"
}
|
(.experimental.cache_file.path) = "/tmp/sing-box/cache.db"
|
(.dns.servers[] | select(.tag=="fakeip-server") | .inet4_range) = "198.20.0.0/15"
|
(.route.rules) |= map(select(.protocol != "quic"))
|
.route.rules = [{"protocol":"quic","inbound":"tproxy-in","outbound":"block"}] + .route.rules
|
if any(.outbounds[]; .tag=="block") then . else .outbounds += [{"type":"block","tag":"block"}] end
|
if any(.outbounds[]; .tag=="direct-out") then . else .outbounds += [{"type":"direct","tag":"direct-out"}] end
|
(.outbounds[] | select(.type=="vless")) |= (
  .transport={"type":"ws","path":"/vpn","headers":{"Host":"vpn2.sharpmaind.ru"}}
  | .tls.alpn=["http/1.1"]
  | .tcp_fast_open=false
  | del(.multiplex)
)
|
(.outbounds[] | select(.tag=="main-urltest-out" and .type=="urltest")) |= (
  .outbounds=["main-2-out","main-1-out"]
  | .interval="1m" | .tolerance=150 | .interrupt_exist_connections=true
)
|
(.outbounds[] | select(.tag=="main-out" and .type=="selector")) |= (
  .outbounds=["main-2-out","main-1-out","main-urltest-out"]
  | .default="main-2-out"
)
'

typ=$(jq -r '.inbounds[]|select(.tag=="tproxy-in")|.type' "$CFG" 2>/dev/null)
if [ "$typ" = "tun" ] && pidof sing-box >/dev/null && ip link show sbtun >/dev/null 2>&1 \
	&& ip route show 198.20.0.0/15 2>/dev/null | grep -q 'dev sbtun' \
	&& ip route show table podkop 2>/dev/null | grep -q 'default dev sbtun'; then
	nft list chain inet fw4 mangle_postrouting 2>/dev/null | grep -q sbtun-mss || \
		nft insert rule inet fw4 mangle_postrouting oifname "sbtun" tcp flags syn tcp option maxseg size set 1360 comment "sbtun-mss"
	nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-out || \
		nft insert rule inet fw4 forward iifname "br-lan" oifname "sbtun" accept comment "sbtun-out"
	nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-in || \
		nft insert rule inet fw4 forward iifname "sbtun" oifname "br-lan" accept comment "sbtun-in"
		finish_hooks
	/usr/bin/wr3000p-kotikey-lock-selector.sh 2>/dev/null || true
	logger -t podkop-tun "sbtun fast-path routes=$(ip route | grep -c 'dev sbtun')"
	exit 0
fi

if [ "$PROXY_CFG" = "urltest" ]; then
	jq "$kotikey_jq" "$CFG" > /tmp/sb-tun.json
else
	jq "$sharp_jq" "$CFG" > /tmp/sb-tun.json
fi

safe_install_cfg /tmp/sb-tun.json || {
	logger -t podkop-tun "jq patch failed — keeping current config"
	rm -f /tmp/sb-tun.json
}

mkdir -p /tmp/sing-box
if ! pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/sing-box start 2>/dev/null || sing-box run -c "$CFG" -D /usr/share/sing-box >/tmp/sb-now.err 2>&1 &
fi

i=0
while ! ip link show sbtun >/dev/null 2>&1 && [ "$i" -lt 90 ]; do sleep 1; i=$((i + 1)); done
if ! ip link show sbtun >/dev/null 2>&1; then
	logger -t podkop-tun "sbtun did not appear — podkop restart"
	/etc/init.d/podkop restart >/tmp/podkop-guard.restart 2>&1 || true
	sleep 8
	/etc/init.d/sing-box start 2>/dev/null || true
fi
ip link set sbtun mtu 1400 2>/dev/null

nft flush chain inet PodkopTable mangle 2>/dev/null || true
nft flush chain inet PodkopTable proxy 2>/dev/null || true
nft flush chain inet PodkopTable mangle_output 2>/dev/null || true
nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-out || \
	nft insert rule inet fw4 forward iifname "br-lan" oifname "sbtun" accept comment "sbtun-out"
nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-in || \
	nft insert rule inet fw4 forward iifname "sbtun" oifname "br-lan" accept comment "sbtun-in"
nft list chain inet fw4 mangle_postrouting 2>/dev/null | grep -q sbtun-mss || \
	nft insert rule inet fw4 mangle_postrouting oifname "sbtun" tcp flags syn tcp option maxseg size set 1360 comment "sbtun-mss"

finish_hooks
/usr/bin/wr3000p-kotikey-lock-selector.sh 2>/dev/null || true
logger -t podkop-tun "sbtun routes=$(ip route | grep -c 'dev sbtun') mode=$PROXY_CFG"