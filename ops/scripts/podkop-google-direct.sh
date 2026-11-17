#!/bin/sh
# MGTS TR3000: YouTube/Google are reachable on WAN; large downloads over CF WebSocket stall.
# Keep them on direct-out with real DNS (not FakeIP / tunnel).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
CFG=/etc/sing-box/config.json
LOCK=/var/lock/sing-box-config.lock
OK=/etc/sing-box/config.json.ok
MARK=/tmp/podkop-google-direct-restart
TAG=podkop-google-direct

[ -s "$CFG" ] || cp "$OK" "$CFG" 2>/dev/null || exit 1
rm -f "$MARK"

(
  flock -n 9 || exit 0
  if jq -e '.dns.rules[]? | select(.server? == "dns-server" and (.domain_suffix? // [] | index("youtube.com")))' "$CFG" >/dev/null 2>&1 \
     && jq -e '.route.rules[]? | select(.outbound? == "direct-out" and (.domain_suffix? // [] | index("youtube.com")))' "$CFG" >/dev/null 2>&1; then
    exit 0
  fi
  jq '
    def google_suffix:
      ["youtube.com","youtu.be","googlevideo.com","ytimg.com","ggpht.com",
       "googleapis.com","gstatic.com","googleusercontent.com","youtubei.googleapis.com"];
    def google_route_rule:
      { action: "route", inbound: "tproxy-in", outbound: "direct-out",
        domain_suffix: google_suffix };
    .dns.rules = (
      [{ action: "route", server: "dns-server", domain_suffix: google_suffix }]
      + (.dns.rules | map(select(
          (.server? != "dns-server") or ((.domain_suffix? // [] | index("youtube.com")) | not)
        )))
    )
    | . as $root
    | ([range(0; ($root.route.rules | length))
        | select($root.route.rules[.].action == "reject" and $root.route.rules[.].protocol == "quic")] | first) as $qi
    | .route.rules = (
        if $qi == null then
          [google_route_rule] + $root.route.rules
        else
          $root.route.rules[0:$qi + 1]
          + [google_route_rule]
          + $root.route.rules[$qi + 1:]
        end
      )
  ' "$CFG" > /tmp/sb.google.json || exit 1
  sing-box check -c /tmp/sb.google.json >/dev/null 2>&1 || exit 1
  cmp -s /tmp/sb.google.json "$CFG" && exit 0
  cp /tmp/sb.google.json "$CFG"
  cp "$CFG" "$OK" 2>/dev/null || true
  touch "$MARK"
  logger -t "$TAG" "YouTube/Google -> direct-out (real DNS)"
) 9>"$LOCK"

[ -f "$MARK" ] || exit 0
rm -f "$MARK"
kill $(pidof sing-box) 2>/dev/null
sleep 1
sing-box run -c "$CFG" -D /usr/share/sing-box >/dev/null 2>&1 &
sleep 2
/usr/bin/podkop-tun-up >/dev/null 2>&1 || true