#!/bin/sh
# TV Xiaomi 192.168.1.164 — DNS only via this router (FakeIP), no public DNS/DoH/QUIC/IPv6
TV=192.168.1.164
R=192.168.1.1

for chain in dstnat forward input; do
  handles=$(nft -a list chain inet fw4 $chain 2>/dev/null | grep -E 'tv-(doh|quic|dns|v6|no-ipv6)' | sed -n 's/.*handle \([0-9]*\).*/\1/p')
  for h in $handles; do nft delete rule inet fw4 $chain handle $h 2>/dev/null; done
done

# Catch DNS to router OR to public resolvers → DNAT to router
nft insert rule inet fw4 dstnat ip saddr $TV udp dport 53 dnat ip to $R:53 comment \"tv-dns-to-router-udp\"
nft insert rule inet fw4 dstnat ip saddr $TV tcp dport 53 dnat ip to $R:53 comment \"tv-dns-to-router-tcp\"
# Block DoH + QUIC
nft insert rule inet fw4 forward ip saddr $TV tcp dport 853 reject with icmp port-unreachable comment \"tv-doh-block\"
nft insert rule inet fw4 forward ip saddr $TV udp dport 853 reject with icmp port-unreachable comment \"tv-doh-udp-block\"
nft insert rule inet fw4 forward ip saddr $TV udp dport 443 reject with icmp port-unreachable comment \"tv-quic-block\"
# No IPv6 from LAN (AAAA blackhole for YT apps)
nft list chain inet fw4 forward 2>/dev/null | grep -q 'tv-no-ipv6' || \
  nft insert rule inet fw4 forward meta nfproto ipv6 iifname \"br-lan\" reject comment \"tv-no-ipv6\"
