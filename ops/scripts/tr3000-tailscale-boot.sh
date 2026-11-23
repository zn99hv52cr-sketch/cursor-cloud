#!/bin/sh
# TR3000: run after podkop/sing-box at boot (and on demand). On this ISP the
# control plane needs the tunnel up; tailscaled still starts at S80, so we wait
# for sing-box, apply the tailnet pin, and restart the daemon only if health says
# the map poll is stale.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOG=/tmp/tailscale-boot.log

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

log "start"

i=0
while [ $i -lt 120 ]; do
	pidof sing-box >/dev/null 2>&1 && \
		[ "$(ip route show table podkop 2>/dev/null | wc -l)" -ge 2 ] && \
		ip link show sbtun >/dev/null 2>&1 && break
	i=$((i + 1))
	sleep 2
done

if ! pidof sing-box >/dev/null 2>&1; then
	log "sing-box still down after wait; starting podkop"
	/etc/init.d/podkop start >/dev/null 2>&1
	sleep 25
fi

[ -x /usr/bin/podkop-restore-table.sh ] && /usr/bin/podkop-restore-table.sh
[ -x /usr/bin/podkop-restore-mangle.sh ] && /usr/bin/podkop-restore-mangle.sh
[ -x /usr/bin/tr3000-tailnet-pin.sh ] && /usr/bin/tr3000-tailnet-pin.sh

NEED=0
J=$(tailscale status --json 2>/dev/null)
[ -n "$J" ] || NEED=1
echo "$J" | grep -q '"BackendState": *"Running"' || NEED=1
echo "$J" 2>/dev/null | grep -qiE \
	"hasn't received a network map|Unable to connect to the Tailscale coordination server" && NEED=1

if [ "$NEED" = "1" ]; then
	log "restarting tailscaled (unhealthy or still warming up)"
	/etc/init.d/tailscale restart >/dev/null 2>&1
	sleep 25
	[ -x /usr/bin/tr3000-tailnet-pin.sh ] && /usr/bin/tr3000-tailnet-pin.sh
else
	log "tailscaled healthy, no restart"
fi

tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null

H=$(tailscale status --json 2>/dev/null | sed -n '/"Health"/,+3p' | tr '\n' ' ')
log "done: sing-box=$(pidof sing-box) peers_online=$(echo "$J" | grep -c '"Online": *true') health=$H"
exit 0