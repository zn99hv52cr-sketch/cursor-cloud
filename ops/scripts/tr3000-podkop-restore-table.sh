#!/bin/sh
# TR3000: podkop policy-routing table loses its default route after podkop-tun-up
# flushes/reinstalls sbtun. fwmark rule 105 then finds no route, marked traffic
# falls back to WAN, and blocked sites (IG/YT/TG) time out while DNS still
# answers fakeip 198.18.x.
# Install: /usr/bin/podkop-restore-table.sh, appended to /usr/bin/podkop-tun-up.
PATH=/usr/sbin:/usr/bin:/sbin:/bin

ip link show sbtun >/dev/null 2>&1 || exit 0

ip route replace default dev sbtun table podkop
ip route replace 198.18.0.0/15 dev sbtun table podkop

logger -t podkop-tun "podkop table default restored"
