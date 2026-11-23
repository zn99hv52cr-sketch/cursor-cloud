#!/bin/sh
# TR3000: remote access (tailscale + dropbear) must survive with podkop OFF.
#
# tailscaled starts at S80; podkop at S99. When sing-box is up, podkop marks LAN
# traffic for the tunnel — that must never touch (a) tailscaled's own sockets
# (mark 0x80000) or (b) packets to tailnet 100.64.0.0/10. Those keep using the
# main table / WAN so you can ssh -p 2222 even if the VPN never came up.
#
# Install: cron every minute, S81tailscale-first boot, last line of podkop-tun-up.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
TAILNET='100.64.0.0/10'
TS_MARK='0x00080000'
LOG=/tmp/tailnet-pin.log

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

# tailscale0 may appear a few seconds after procd starts tailscaled
for _ in 1 2 3 4 5 6 7 8 9 10; do
	ip link show tailscale0 >/dev/null 2>&1 && break
	sleep 2
done
ip link show tailscale0 >/dev/null 2>&1 || { log "tailscale0 absent"; exit 0; }

ip route show | grep -q "^$TAILNET dev tailscale0" || {
	ip route replace "$TAILNET" dev tailscale0
	log "restored main route $TAILNET dev tailscale0"
}

ip rule show | grep -q "$TAILNET" || {
	ip rule add to "$TAILNET" table main priority 90 2>/dev/null
	log "added ip rule 90: to $TAILNET table main"
}
ip route replace "$TAILNET" dev tailscale0 table podkop 2>/dev/null

if nft list table inet PodkopTable >/dev/null 2>&1; then
	for ch in mangle_output mangle; do
		nft list chain inet PodkopTable "$ch" >/dev/null 2>&1 || continue
		nft list chain inet PodkopTable "$ch" 2>/dev/null | grep -q "$TS_MARK" || {
			nft insert rule inet PodkopTable "$ch" \
				meta mark and 0x00ff0000 == "$TS_MARK" counter return 2>/dev/null \
				&& log "nft: $ch bypasses tailscaled mark 0x80000"
		}
		nft list chain inet PodkopTable "$ch" 2>/dev/null | grep -q "$TAILNET" || {
			nft insert rule inet PodkopTable "$ch" ip daddr "$TAILNET" counter return 2>/dev/null \
				&& log "nft: $ch returns $TAILNET"
		}
	done
	nft list chain inet PodkopTable mangle 2>/dev/null | grep -q 'iifname "tailscale0"' || {
		nft insert rule inet PodkopTable mangle iifname "tailscale0" counter return 2>/dev/null \
			&& log "nft: mangle returns iif tailscale0"
	}
fi

pidof dropbear >/dev/null 2>&1 || { /etc/init.d/dropbear start; log "dropbear was down, started"; }
netstat -lnt 2>/dev/null | grep -q ':2222 ' || {
	uci -q set dropbear.alt=dropbear
	uci -q set dropbear.alt.enable='1'
	uci -q set dropbear.alt.Port='2222'
	uci -q set dropbear.alt.Interface=''
	uci -q commit dropbear
	/etc/init.d/dropbear restart
	log "re-created dropbear :2222"
}

tailscale status >/dev/null 2>&1 && {
	tailscale status --json 2>/dev/null | grep -q '"RunSSH": *true' && {
		tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null
		log "turned RunSSH off"
	}
}

exit 0