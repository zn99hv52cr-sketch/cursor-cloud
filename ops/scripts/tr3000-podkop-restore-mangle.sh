#!/bin/sh
# TR3000: re-add Podkop nft mangle after podkop-tun-up flush (custom tun-up clears rules).
# Install: append to /usr/bin/podkop-tun-up after routes: /usr/bin/podkop-restore-mangle.sh
# Or run once after podkop restart/reboot if posters break but video works.
set -e

MARK=0x00100000
T=PodkopTable

if nft list chain inet "$T" mangle 2>/dev/null | grep -q "counter packets"; then
  exit 0
fi

nft add rule inet "$T" mangle ct status dnat return 2>/dev/null || true
nft add rule inet "$T" mangle iifname @interfaces ip daddr @podkop_subnets meta l4proto tcp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr @podkop_subnets meta l4proto udp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.18.0.0/15 meta l4proto tcp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.18.0.0/15 meta l4proto udp meta mark set "$MARK" counter
nft add rule inet "$T" proxy meta mark \& "$MARK" == "$MARK" meta l4proto tcp tproxy ip to 127.0.0.1:1602 counter 2>/dev/null || true
nft add rule inet "$T" proxy meta mark \& "$MARK" == "$MARK" meta l4proto udp tproxy ip to 127.0.0.1:1602 counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @localv4 return 2>/dev/null || true
nft add rule inet "$T" mangle_output meta mark 0x00200000 counter return 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @podkop_subnets meta l4proto tcp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @podkop_subnets meta l4proto udp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.18.0.0/15 meta l4proto tcp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.18.0.0/15 meta l4proto udp meta mark set "$MARK" counter 2>/dev/null || true
logger -t podkop-tun "mangle rules restored"