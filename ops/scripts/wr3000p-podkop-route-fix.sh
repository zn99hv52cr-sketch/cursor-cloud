#!/bin/sh
# WR3000P: policy table podkop + main-table FakeIP/Google/TG stubs → sbtun.
[ -d /sys/class/net/sbtun ] || exit 0
need=0
ip route show table podkop 2>/dev/null | grep -q "default dev sbtun" || need=1
ip route show 198.20.0.0/15 2>/dev/null | grep -q 'dev sbtun' || need=1
[ "$need" -eq 0 ] && exit 0

ip route flush table podkop 2>/dev/null || true
ip route add default dev sbtun table podkop 2>/dev/null || true
ip route add 198.18.0.0/15 dev sbtun table podkop 2>/dev/null || true
ip route add 198.20.0.0/15 dev sbtun table podkop 2>/dev/null || true
ip route replace 198.18.0.0/15 dev sbtun 2>/dev/null || true
ip route replace 198.20.0.0/15 dev sbtun 2>/dev/null || true
logger -t wr-podkop-route "podkop+main fakeip routes fixed"