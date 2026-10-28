#!/bin/sh
# Deploy on TR3000: logs iPhone Air (a6:c5:ff:0d:e9:60) Wi-Fi state to /root/log/iphone-air-wifi.log
MAC="a6:c5:ff:0d:e9:60"
LOG="/root/log/iphone-air-wifi.log"
MAX=131072
mkdir -p /root/log

trim_log() {
	[ -f "$LOG" ] || return 0
	sz=$(wc -c < "$LOG")
	[ "$sz" -gt "$MAX" ] || return 0
	tail -c "$MAX" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
}

log_line() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
	trim_log
}

find_if() {
	if iw dev phy1-ap0 station dump 2>/dev/null | grep -qi "$MAC"; then
		echo phy1-ap0
	elif iw dev phy0-ap0 station dump 2>/dev/null | grep -qi "$MAC"; then
		echo phy0-ap0
	fi
}

snapshot() {
	IF=$(find_if)
	if [ -z "$IF" ]; then
		log_line "STATE=offline"
		return 0
	fi
	log_line "$IF $(iw dev "$IF" station dump 2>/dev/null | grep -iA12 "$MAC" | tr '\n' ' | ')"
}

case "$1" in
snapshot) snapshot ;;
snapshot-loop)
	log_line "=== snapshot-loop started ==="
	while true; do
		snapshot
		sleep 30
	done
	;;
follow)
	log_line "=== follow logread started ==="
	logread -f 2>/dev/null | grep -i --line-buffered "$MAC" | while read -r line; do
		log_line "EV $line"
	done
	;;
*) snapshot ;;
esac
