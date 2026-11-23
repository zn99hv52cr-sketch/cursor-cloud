#!/bin/sh
# WR3000P: restore podkop nft after tun-up flush; WR DNS uses 198.20.0.0/15 fakeip.
set -e
MARK=0x00100000
T=PodkopTable

need=0
nft list chain inet "$T" mangle 2>/dev/null | grep -q "198.20.0.0/15" || need=1
nft list chain inet "$T" proxy 2>/dev/null | grep -q "127.0.0.1:1602" || need=1
[ "$need" -eq 0 ] && exit 0

# Remove broken half-rules: flush mangle/proxy if 198.20 missing or proxy empty
if ! nft list chain inet "$T" mangle 2>/dev/null | grep -q "198.20.0.0/15"; then
	nft flush chain inet "$T" mangle 2>/dev/null || true
	nft flush chain inet "$T" proxy 2>/dev/null || true
fi

nft add rule inet "$T" mangle ct status dnat return 2>/dev/null || true
nft add rule inet "$T" mangle iifname @interfaces ip daddr @podkop_subnets meta l4proto tcp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr @podkop_subnets meta l4proto udp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.18.0.0/15 meta l4proto tcp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.18.0.0/15 meta l4proto udp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.20.0.0/15 meta l4proto tcp meta mark set "$MARK" counter
nft add rule inet "$T" mangle iifname @interfaces ip daddr 198.20.0.0/15 meta l4proto udp meta mark set "$MARK" counter
nft add rule inet "$T" proxy meta mark \& "$MARK" == "$MARK" meta l4proto tcp tproxy ip to 127.0.0.1:1602 counter 2>/dev/null || true
nft add rule inet "$T" proxy meta mark \& "$MARK" == "$MARK" meta l4proto udp tproxy ip to 127.0.0.1:1602 counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @localv4 return 2>/dev/null || true
nft add rule inet "$T" mangle_output meta mark 0x00200000 counter return 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @podkop_subnets meta l4proto tcp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr @podkop_subnets meta l4proto udp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.18.0.0/15 meta l4proto tcp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.18.0.0/15 meta l4proto udp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.20.0.0/15 meta l4proto tcp meta mark set "$MARK" counter 2>/dev/null || true
nft add rule inet "$T" mangle_output ip daddr 198.20.0.0/15 meta l4proto udp meta mark set "$MARK" counter 2>/dev/null || true
logger -t podkop-tun "wr mangle rules restored (198.18+198.20)"