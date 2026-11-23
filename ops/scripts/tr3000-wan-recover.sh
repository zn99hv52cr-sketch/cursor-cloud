#!/bin/sh
# TR3000 WAN recovery (deploy: /usr/bin/tr3000-wan-recover). Called from usb-vpn-start @ boot and hotplug ifup.
LOCK=/tmp/tr3000-wan-recover.lock
LOGTAG=tr3000-wan-recover
REASON=${1:-manual}

if [ -f "$LOCK" ]; then
	age=$(( $(date +%s) - $(cat "$LOCK" 2>/dev/null || echo 0) ))
	[ "$age" -lt 20 ] && exit 0
fi
date +%s > "$LOCK"
logger -t "$LOGTAG" "start reason=$REASON"

[ -x /etc/init.d/usb-data-mount ] && /etc/init.d/usb-data-mount start >/dev/null 2>&1 || true
insmod /lib/modules/$(uname -r)/tun.ko 2>/dev/null || modprobe tun 2>/dev/null || true

i=0
while [ $i -lt 90 ]; do
	ip -4 route | grep -q '^default ' && break
	i=$((i + 1))
	sleep 1
done
if ! ip -4 route | grep -q '^default '; then
	logger -t "$LOGTAG" "no default route yet, abort"
	exit 1
fi

mkdir -p /tmp/sing-box/rulesets
if command -v jq >/dev/null 2>&1; then
	uci -q get podkop.main.user_domains | tr ' ' '\n' | jq -R -s 'split("\n")|map(select(length>0))|{version:3,rules:[{domain_suffix:.}]}' > /tmp/sing-box/rulesets/main-user-domains-ruleset.json
	uci -q get podkop.main.user_subnets | tr ' ' '\n' | jq -R -s 'split("\n")|map(select(length>0))|{version:3,rules:[{ip_cidr:.}]}' > /tmp/sing-box/rulesets/main-user-subnets-ruleset.json
fi

# podkop reload on boot raced with S99podkop: sing-box already up -> reload flushed nft and cleared mangle.
podkop_ensure_up() {
	if pidof sing-box >/dev/null 2>&1; then
		return 0
	fi
	if [ "$REASON" = "boot" ]; then
		i=0
		while [ $i -lt 120 ]; do
			pidof sing-box >/dev/null 2>&1 && return 0
			sleep 1
			i=$((i + 1))
		done
	fi
	logger -t "$LOGTAG" "sing-box missing -> podkop start"
	[ -x /usr/bin/podkop ] && /usr/bin/podkop start >/tmp/podkop-wan-recover.log 2>&1 || true
	sleep 3
}

if [ "$REASON" = "boot" ]; then
	podkop_ensure_up
	logger -t "$LOGTAG" "boot: skip podkop reload (procd S99podkop)"
else
	if ! pidof sing-box >/dev/null 2>&1 || ! ip link show sbtun >/dev/null 2>&1; then
		podkop_ensure_up
	else
		logger -t "$LOGTAG" "$REASON: sing-box/sbtun ok, skip reload"
	fi
fi

[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up >/tmp/tun-wan-recover.log 2>&1 || true
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh || true

# NEVER: full tailscale restart, NEVER: --ssh (kills cloud :2222 / enables RunSSH on :22)
if ! pidof tailscaled >/dev/null 2>&1; then
	[ -x /etc/init.d/tailscale ] && /etc/init.d/tailscale start
	sleep 5
fi
if [ -x /usr/sbin/tailscale ] && [ -S /var/run/tailscale/tailscaled.sock ]; then
	/usr/sbin/tailscale --socket /var/run/tailscale/tailscaled.sock set \
		--ssh=false --accept-risk=lose-ssh 2>/dev/null || true
	/usr/sbin/tailscale --socket /var/run/tailscale/tailscaled.sock set \
		--advertise-routes=192.168.2.0/24,192.168.1.254/32 \
		--accept-dns=false 2>/dev/null || \
	/usr/sbin/tailscale --socket /var/run/tailscale/tailscaled.sock up \
		--accept-dns=false \
		--advertise-routes=192.168.2.0/24,192.168.1.254/32 \
		--hostname=cudy-tr3000 \
		--ssh=false \
		--accept-risk=lose-ssh >/tmp/tailscale-up.log 2>&1 || true
fi

ok_sb=0
ok_tun=0
ok_ts=0
pidof sing-box >/dev/null && ok_sb=1
ip link show sbtun >/dev/null 2>&1 && ok_tun=1
pidof tailscaled >/dev/null && ok_ts=1
logger -t "$LOGTAG" "done sing-box=$ok_sb sbtun=$ok_tun tailscale=$ok_ts routes=$(ip route | grep -c sbtun 2>/dev/null || echo 0)"
exit 0