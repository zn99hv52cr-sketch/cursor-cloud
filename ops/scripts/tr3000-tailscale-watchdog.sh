#!/bin/sh
# TR3000: notice when tailscaled's control connection is frozen and revive it.
#
# A frozen map poll is what made remote access "fall off": tailscaled keeps its
# DERP socket, so disco pings still answer and the node looks alive, while its
# netmap goes stale and every real session (both directions) dies. Nothing in
# OpenWrt notices that on its own.
#
# Install: /usr/bin/tr3000-tailscale-watchdog.sh + cron every 5 minutes.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
STAMP=/tmp/ts-watchdog.last
LOG=/tmp/ts-watchdog.log
COOLDOWN=900

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

command -v tailscale >/dev/null 2>&1 || exit 0
J=$(tailscale status --json 2>/dev/null)
[ -n "$J" ] || { log "tailscaled not answering"; NEED=1; }

NEED=${NEED:-0}
echo "$J" | grep -q '"BackendState": *"Running"' || { NEED=1; log "BackendState not Running"; }
echo "$J" | grep -qiE 'not in map poll|map poll|derp.*unreachable' && { NEED=1; log "health complains about map poll/DERP"; }

# No peer online at all, yet the WAN is fine -> the netmap is stale, not the peers.
PEERS_ONLINE=$(echo "$J" | grep -c '"Online": *true')
if [ "$PEERS_ONLINE" -le 1 ]; then
	if curl -4 -sS -m 6 -o /dev/null https://1.1.1.1/ 2>/dev/null; then
		NEED=1
		log "no peer online while WAN is up (online=$PEERS_ONLINE)"
	fi
fi

[ "$NEED" = "1" ] || exit 0

NOW=$(date +%s)
LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -lt "$COOLDOWN" ]; then
	log "revive skipped, cooldown"
	exit 0
fi
echo "$NOW" >"$STAMP"

tailscale debug prefs >/root/tailscale-prefs-before.json 2>/dev/null
log "restarting tailscaled"
/etc/init.d/tailscale restart >/dev/null 2>&1
sleep 20

/usr/bin/tr3000-tailnet-pin.sh 2>/dev/null
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null

S=$(tailscale status 2>&1 | head -3)
log "after restart: $(echo "$S" | tr '\n' ' ')"
echo "$S" | grep -qi 'logged out\|NeedsLogin' && \
	logger -t ts-watchdog "TAILSCALE LOGGED OUT after restart, needs auth key"
exit 0
