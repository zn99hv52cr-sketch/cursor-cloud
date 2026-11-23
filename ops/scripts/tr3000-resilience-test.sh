#!/bin/sh
# TR3000: prove that remote access repairs itself after the two events that used
# to kill it — someone wiping the podkop bypass rules, and a full podkop restart.
#
# Run detached on the router, it writes /tmp/resilience-test.log, so the result
# survives even if the agent's own session drops mid-test:
#   nohup sh /tmp/tr3000-resilience-test.sh >/dev/null 2>&1 &
PATH=/usr/sbin:/usr/bin:/sbin:/bin
AGENT_TS_IP="100.66.76.102"
LOG=/tmp/resilience-test.log
exec >"$LOG" 2>&1

say() { echo; echo "### $(date '+%H:%M:%S') $*"; }

state() {
	echo "nft bypass rules : $(nft list table inet PodkopTable 2>/dev/null | grep -c '0x00080000')"
	echo "nft tailnet rules: $(nft list table inet PodkopTable 2>/dev/null | grep -c '100.64.0.0/10')"
	echo "ip rule 90       : $(ip rule show | grep -c '100.64.0.0/10')"
	echo "podkop routes    : $(ip route show table podkop 2>/dev/null | wc -l)"
	echo "sing-box pid     : $(pidof sing-box)"
	echo "dropbear 2222    : $(netstat -lnt 2>/dev/null | grep -c ':2222 ')"
	# No timeout applet in this busybox; tailscale ping gives up on its own.
	echo "agent ping       : $(tailscale ping -c 1 "$AGENT_TS_IP" 2>&1 | head -1)"
	echo "agent tcp 9999   : $(curl -sS -m 6 -o /dev/null -w '%{http_code}' "http://$AGENT_TS_IP:9999/" 2>/dev/null)"
}

health() {
	echo "youtube=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://www.youtube.com/generate_204 2>/dev/null)" \
	     "instagram=$(curl -4 -sS -m12 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)" \
	     "telegram=$(curl -4 -sS -m10 -o /dev/null -w '%{http_code}' https://web.telegram.org/ 2>/dev/null)" \
	     "node=$(curl -sS -m5 http://192.168.2.1:9090/proxies/main-out 2>/dev/null | grep -o '"now": *"[^"]*"')"
}

say "BASELINE"
state
health

say "TEST A: wipe the bypass rules and the tailnet ip rule, then wait for cron"
for ch in mangle mangle_output; do
	nft -a list chain inet PodkopTable "$ch" 2>/dev/null \
		| grep -E '0x00080000|100.64.0.0/10|tailscale0' \
		| sed -n 's/.*handle \([0-9]*\)$/\1/p' \
		| while read -r h; do nft delete rule inet PodkopTable "$ch" handle "$h" 2>/dev/null; done
done
ip rule del to 100.64.0.0/10 table main priority 90 2>/dev/null || ip rule del pref 90 2>/dev/null
echo "-- right after the wipe:"
state

say "waiting 80 s for the per-minute pin"
sleep 80
echo "-- after cron:"
state
echo "-- pin log:"
tail -6 /tmp/tailnet-pin.log

say "TEST B: full podkop restart (the event that used to break access)"
/etc/init.d/podkop restart >/dev/null 2>&1
echo "restart issued"
for i in 1 2 3 4 5 6; do
	sleep 30
	echo "-- +$((i * 30)) s:"
	state
	health
done

say "RESULT"
state
health
echo "-- pin log tail:"
tail -10 /tmp/tailnet-pin.log
echo "-- watchdog log tail:"
tail -5 /tmp/ts-watchdog.log 2>/dev/null || echo "(watchdog never had to act)"
say "DONE"
