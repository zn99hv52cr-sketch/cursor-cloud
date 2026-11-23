#!/bin/sh
STATUS=/etc/rc.local
write_status() {
  if ! grep -q "wr-status-begin" "$STATUS" 2>/dev/null; then
    printf '\n# wr-status-begin\n# wr-status-end\n' >> "$STATUS"
  fi
  tmp=/tmp/rc.local.new
  awk '
    BEGIN{skip=0}
    /wr-status-begin/{print; skip=1; next}
    /wr-status-end/{skip=0; while ((getline line < "/tmp/wr-status.body")>0) print line; close("/tmp/wr-status.body"); print; next}
    skip{next}
    {print}
  ' "$STATUS" > "$tmp" && mv "$tmp" "$STATUS"
  chmod 755 "$STATUS"
}

case "$1" in
  diag)
    {
      echo "# ts=$(date '+%F %T')"
      echo "# sbtun=$(ip -br link show sbtun 2>/dev/null | tr -s ' ')"
      echo "# quic=$(grep -c '\"protocol\": \"quic\"' /etc/sing-box/config.json 2>/dev/null || echo 0)"
      echo "# r19818=$(ip route | grep -c '198.18.0.0/15' || true)"
      echo "# tv_rule=$(ip rule | grep -c '192.168.1.164' || true)"
      echo "# tv_dns_nat=$(nft list chain inet fw4 dstnat 2>/dev/null | grep -c tv-dns-real || true)"
      echo "# tv_quic=$(nft list chain inet fw4 forward 2>/dev/null | grep -c tv-quic || true)"
      echo "# leases=$(wc -l </tmp/dhcp.leases 2>/dev/null || echo 0)"
      echo "# fakeip_ok=see-podkop"
      ip rule | grep 192.168.1.164 | sed 's/^/# rule: /'
      ip route show table 164 2>/dev/null | sed 's/^/# tbl164: /'
      nft list chain inet fw4 dstnat 2>/dev/null | grep tv- | sed 's/^/# nat: /'
      nft list chain inet fw4 forward 2>/dev/null | grep tv- | sed 's/^/# fwd: /'
      cat /tmp/dhcp.leases 2>/dev/null | sed 's/^/# lease: /'
    } > /tmp/wr-status.body
    write_status
    ;;
  tv-policy)
    # All IPv4 from TV goes into sbtun; sing-box sniffs SNI and routes YT via VPN
    ip rule del from 192.168.1.164 table 164 2>/dev/null
    ip route flush table 164 2>/dev/null
    ip route add default dev sbtun table 164 2>/dev/null || true
    ip route add 192.168.1.0/24 dev br-lan table 164 2>/dev/null || true
    # disabled public DNS route:     ip route add 1.1.1.1 via $(ip route | awk '/default/ {print $3; exit}') dev wan table 164 2>/dev/null || \
    # disabled public DNS route:       ip route add 1.1.1.1/32 via 10.68.0.1 dev wan table 164 2>/dev/null || true
    # Keep local router reachable
    ip route add 192.168.1.1/32 dev br-lan table 164 2>/dev/null || true
    ip rule add from 192.168.1.164 table 164 priority 164
    # DNS + QUIC bits
    # disabled TV FakeIP bypass:     nft list chain inet fw4 dstnat 2>/dev/null | grep -q tv-dns-real-udp || nft insert rule inet fw4 dstnat ip saddr 192.168.1.164 udp dport 53 counter dnat to 1.1.1.1:53 comment "tv-dns-real-udp" 2>/dev/null
    # disabled TV FakeIP bypass:     nft list chain inet fw4 dstnat 2>/dev/null | grep -q tv-dns-real-tcp || nft insert rule inet fw4 dstnat ip saddr 192.168.1.164 tcp dport 53 counter dnat to 1.1.1.1:53 comment "tv-dns-real-tcp" 2>/dev/null
    # disabled:     nft list chain inet fw4 forward 2>/dev/null | grep -q tv-dns-allow || nft insert rule inet fw4 forward ip saddr 192.168.1.164 ip daddr 1.1.1.1 udp dport 53 counter accept comment "tv-dns-allow" 2>/dev/null
    nft list chain inet fw4 forward 2>/dev/null | grep -q tv-quic-block || nft insert rule inet fw4 forward ip saddr 192.168.1.164 udp dport 443 counter reject comment "tv-quic-block" 2>/dev/null
    nft list chain inet fw4 forward 2>/dev/null | grep -q tv-doh-block || nft insert rule inet fw4 forward ip saddr 192.168.1.164 tcp dport 853 counter reject comment "tv-doh-block" 2>/dev/null
    [ -x /usr/bin/tv-yt-policy ] && /usr/bin/tv-yt-policy
    # Ensure sbtun forward accept
    nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-out || nft insert rule inet fw4 forward iifname "br-lan" oifname "sbtun" accept comment "sbtun-out" 2>/dev/null
    nft list chain inet fw4 forward 2>/dev/null | grep -q sbtun-in || nft insert rule inet fw4 forward iifname "sbtun" oifname "br-lan" accept comment "sbtun-in" 2>/dev/null
    logger -t wr-boot tv-policy-applied
    /usr/bin/wr-helper diag
    ;;
  *) echo usage; exit 1;;
esac
