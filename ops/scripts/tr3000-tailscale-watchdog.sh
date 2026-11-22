#!/bin/sh
# TR3000: notice when tailscaled lost its control plane and revive it.
#
# This is the failure that kept taking remote access down: tailscaled keeps its
# DERP socket, so the node still looks alive, while its netmap goes stale, peers
# show "offline, last seen N min ago" and no TCP session completes in either
# direction. Nothing in OpenWrt notices that on its own.
#
# The health strings below are the ones tailscaled actually emits; an earlier
# version looked for "map poll" and never matched, so the watchdog stayed blind.
#
# Install: /usr/bin/tr3000-tailscale-watchdog.sh + cron every 5 minutes.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
STAMP=/tmp/ts-watchdog.last
LOG=/tmp/ts-watchdog.log
USB_LOG=/mnt/usb/backups/ts-watchdog.log
COOLDOWN=900

log() {
	echo "$(date '+%F %T') $*" >>"$LOG"
	[ -d /mnt/usb/backups ] && echo "$(date '+%F %T') $*" >>"$USB_LOG"
}

command -v tailscale >/dev/null 2>&1 || exit 0

NEED=0
J=$(tailscale status --json 2>/dev/null)
[ -n "$J" ] || { NEED=1; log "tailscaled not answering"; }

echo "$J" | grep -q '"BackendState": *"Running"' || { NEED=1; log "BackendState not Running"; }
echo "$J" | grep -qiE "hasn't received a network map|Unable to connect to the Tailscale coordination server|not in map poll|state=Stopped" \
	&& { NEED=1; log "control plane unhealthy"; }

# No peer online at all while the WAN is fine means the netmap is stale, not
# that every peer really went away.
PEERS_ONLINE=$(echo "$J" | grep -c '"Online": *true')
if [ "$PEERS_ONLINE" -le 1 ] && curl -4 -sS -m 6 -o /dev/null https://1.1.1.1/ 2>/dev/null; then
	NEED=1
	log "no peer online while WAN is up (online=$PEERS_ONLINE)"
fi

[ "$NEED" = "1" ] || exit 0

NOW=$(date +%s)
LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -lt "$COOLDOWN" ]; then
	log "revive skipped, cooldown"
	exit 0
fi
echo "$NOW" >"$STAMP"

# The tunnel carries tailscale's control plane on this ISP, so make sure it is
# up before asking tailscaled to re-dial.
pidof sing-box >/dev/null 2>&1 || {
	log "sing-box down, starting podkop first"
	/usr/bin/podkop start >/dev/null 2>&1
	sleep 20
}
[ "$(ip route show table podkop 2>/dev/null | wc -l)" -lt 3 ] && /usr/bin/podkop-restore-table.sh

tailscale debug prefs >/root/tailscale-prefs-before.json 2>/dev/null
log "restarting tailscaled"
/etc/init.d/tailscale restart >/dev/null 2>&1
sleep 30
/usr/bin/tr3000-tailnet-pin.sh 2>/dev/null
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null

J2=$(tailscale status --json 2>/dev/null)
ONLINE2=$(echo "$J2" | grep -c '"Online": *true')
if echo "$J2" | grep -qiE "hasn't received a network map|Unable to connect to the Tailscale coordination server"; then
	log "still unhealthy after restart (online=$ONLINE2)"
else
	log "control plane healthy again (online=$ONLINE2)"
fi
echo "$J2" | grep -qi '"NeedsLogin"\|logged out' && \
	logger -t ts-watchdog "TAILSCALE NEEDS LOGIN, prefs in /root/tailscale-prefs-before.json"
exit 0
