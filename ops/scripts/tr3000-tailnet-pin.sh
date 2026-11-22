#!/bin/sh
# TR3000: keep the plumbing remote access needs, without touching how
# tailscaled's own traffic leaves the box.
#
# What this does NOT do any more: it used to insert
# "meta mark and 0xff0000 == 0x80000 return" into PodkopTable, which pushed
# tailscaled's control-plane and DERP sockets onto the direct WAN path. On this
# ISP the direct path to Tailscale does not work, so the daemon lost its map
# poll and every session died. That rule is now actively removed if found.
#
# Install: /usr/bin/tr3000-tailnet-pin.sh + cron every minute + boot init +
# last line of /usr/bin/podkop-tun-up.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
TAILNET='100.64.0.0/10'
LOG=/tmp/tailnet-pin.log

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

ip link show tailscale0 >/dev/null 2>&1 || { log "tailscale0 absent"; exit 0; }

# 1) tailnet must resolve through tailscale0 in the main table.
ip route show | grep -q "^$TAILNET dev tailscale0" || {
	ip route replace "$TAILNET" dev tailscale0
	log "restored main route $TAILNET dev tailscale0"
}

# 2) tailnet lookups jump to main before podkop's fwmark rule (priority 105)
#    and before sing-box's auto_route rules, so replies to tailnet peers are
#    never sent into the tunnel.
ip rule show | grep -q "$TAILNET" || {
	ip rule add to "$TAILNET" table main priority 90 2>/dev/null
	log "added ip rule 90: to $TAILNET table main"
}
ip route replace "$TAILNET" dev tailscale0 table podkop 2>/dev/null

if nft list table inet PodkopTable >/dev/null 2>&1; then
	# 3) packets addressed to tailnet peers must not be marked for podkop.
	for ch in mangle_output mangle; do
		nft list chain inet PodkopTable "$ch" >/dev/null 2>&1 || continue
		nft list chain inet PodkopTable "$ch" 2>/dev/null | grep -q "$TAILNET" || {
			nft insert rule inet PodkopTable "$ch" ip daddr "$TAILNET" counter return 2>/dev/null \
				&& log "nft: $ch returns $TAILNET"
		}
	done
	nft list chain inet PodkopTable mangle 2>/dev/null | grep -q 'iifname "tailscale0"' || {
		nft insert rule inet PodkopTable mangle iifname "tailscale0" counter return 2>/dev/null \
			&& log "nft: mangle returns iif tailscale0"
	}

	# 4) drop the harmful bypass if an older version of this script left it.
	for ch in mangle_output mangle; do
		nft -a list chain inet PodkopTable "$ch" 2>/dev/null | grep '0x00080000' \
			| sed -n 's/.*handle \([0-9]*\)$/\1/p' | while read -r h; do
			nft delete rule inet PodkopTable "$ch" handle "$h" 2>/dev/null \
				&& log "nft: removed tailscale mark bypass from $ch"
		done
	done
fi

# 5) tailscale infrastructure must keep resolving the way the tunnel expects.
#    Forcing it to a plain upstream resolver bypasses the tunnel and breaks the
#    control plane on this ISP.
[ -f /etc/dnsmasq.d/tailscale-direct.conf ] && {
	rm -f /etc/dnsmasq.d/tailscale-direct.conf
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
	log "removed tailscale-direct.conf and restarted dnsmasq"
}

# 6) dropbear :2222 must stay reachable from the tailscale zone.
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

# 7) tailscale's own SSH server must stay off; it hijacks port 22 and fights dropbear.
tailscale status >/dev/null 2>&1 && {
	tailscale status --json 2>/dev/null | grep -q '"RunSSH": *true' && {
		tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null
		log "turned RunSSH off"
	}
}

exit 0
