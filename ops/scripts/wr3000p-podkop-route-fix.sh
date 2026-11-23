#!/bin/sh
# WR3000P: podkop table must default via sbtun (not dev lo). FakeIP 198.20 + 198.18.
[ -d /sys/class/net/sbtun ] || exit 0
ip route show table podkop 2>/dev/null | grep -q "default dev sbtun" && exit 0
ip route flush table podkop 2>/dev/null || true
ip route add default dev sbtun table podkop 2>/dev/null || true
ip route add 198.18.0.0/15 dev sbtun table podkop 2>/dev/null || true
ip route add 198.20.0.0/15 dev sbtun table podkop 2>/dev/null || true
logger -t wr-podkop-route "podkop table fixed"