#!/bin/sh
# TR3000: keep the tailnet (100.64.0.0/10) outside podkop's policy routing.
#
# Why this exists: podkop's rule "from all fwmark 0x100000 lookup podkop" plus
# "default dev sbtun" in table podkop swallows packets the router sends back to
# tailnet peers. DERP disco pings still answer (tailscaled replies inside its
# already-open DERP socket), so the node looks alive while every inbound TCP
# session dies with "tx N rx 0". Every podkop/sing-box restart re-created that
# state, which is why remote access kept dropping.
#
# Install: /usr/bin/tr3000-tailnet-pin.sh + cron every minute + boot init.
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
#    and before sing-box's auto_route rules.
ip rule show | grep -q "$TAILNET" || {
	ip rule add to "$TAILNET" table main priority 90 2>/dev/null
	log "added ip rule 90: to $TAILNET table main"
}

# 3) belt and braces: even inside table podkop, tailnet goes out tailscale0.
ip route replace "$TAILNET" dev tailscale0 table podkop 2>/dev/null

# 4) stop podkop's nftables chains from touching tailscale traffic at all.
#    The mark bypass matters most: tailscaled stamps its own sockets (control
#    plane and DERP) with 0x80000, and without this they get marked for the
#    podkop table, resolve through fakeip and die on every sing-box restart —
#    which froze the router's netmap and made peers look offline.
if nft list table inet PodkopTable >/dev/null 2>&1; then
	for ch in mangle_output mangle; do
		nft list chain inet PodkopTable "$ch" >/dev/null 2>&1 || continue
		nft list chain inet PodkopTable "$ch" 2>/dev/null | grep -q '0x00080000' || {
			nft insert rule inet PodkopTable "$ch" \
				meta mark and 0x00ff0000 == 0x00080000 counter return 2>/dev/null \
				&& log "nft: $ch bypasses tailscale mark 0x80000"
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

# 5) tailscale infrastructure must resolve to real IPs, never to fakeip.
DNSCONF=/etc/dnsmasq.d/tailscale-direct.conf
[ -f "$DNSCONF" ] || {
	cat > "$DNSCONF" << 'EOF'
server=/tailscale.com/1.1.1.1
server=/tailscale.io/1.1.1.1
EOF
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
	log "created $DNSCONF and restarted dnsmasq"
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
