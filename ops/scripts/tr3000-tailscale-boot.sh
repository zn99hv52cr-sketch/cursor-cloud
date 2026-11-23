#!/bin/sh
# TR3000: reinforce tailscale right after the daemon starts (S81), without
# waiting for podkop. Use when the tunnel is down on purpose or broken — ssh
# must still work over the tailnet.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
LOG=/tmp/tailscale-boot.log

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
log "start (independent of podkop)"

i=0
while [ $i -lt 45 ]; do
	ip link show tailscale0 >/dev/null 2>&1 && break
	i=$((i + 1))
	sleep 2
done

[ -x /usr/bin/tr3000-tailnet-pin.sh ] && /usr/bin/tr3000-tailnet-pin.sh

NEED=0
J=$(tailscale status --json 2>/dev/null)
[ -n "$J" ] || NEED=1
echo "$J" | grep -q '"BackendState": *"Running"' || NEED=1
echo "$J" 2>/dev/null | grep -qiE \
	"hasn't received a network map|Unable to connect to the Tailscale coordination server" && NEED=1

if [ "$NEED" = "1" ]; then
	log "restarting tailscaled (unhealthy)"
	/etc/init.d/tailscale restart >/dev/null 2>&1
	sleep 20
	[ -x /usr/bin/tr3000-tailnet-pin.sh ] && /usr/bin/tr3000-tailnet-pin.sh
else
	log "tailscaled healthy, no restart"
fi

tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null
log "done: sing-box=$(pidof sing-box 2>/dev/null || echo 0) podkop_routes=$(ip route show table podkop 2>/dev/null | wc -l)"
exit 0