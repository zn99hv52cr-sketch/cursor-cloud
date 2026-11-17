#!/bin/sh
# TR3000 (MGTS): after podkop generates config, pin home.sharpmaind.ru to fast CF edges.
# Deploy to router as /usr/bin/podkop-mgts-tune.sh — see ops/tr3000-chatgpt-tunnel.md context.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
CFG=/etc/sing-box/config.json
LOCK=/var/lock/sing-box-config.lock
OK=/etc/sing-box/config.json.ok
CF_A=104.16.230.132
CF_B=104.16.231.132

[ -s "$CFG" ] || cp "$OK" "$CFG" 2>/dev/null || exit 1

(
  flock -n 9 || exit 0
  if jq -e '.outbounds[] | select(.tag == "cf-urltest-out")' "$CFG" >/dev/null 2>&1; then
    exit 0
  fi
  jq --arg cf_a "$CF_A" --arg cf_b "$CF_B" '
    .dns.servers = (
      [{
        type: "hosts",
        tag: "cf-hosts-dns",
        predefined: { "home.sharpmaind.ru": [$cf_a, $cf_b] }
      }] + .dns.servers
    )
    | .dns.rules = (
      [{ action: "route", server: "cf-hosts-dns", domain: ["home.sharpmaind.ru"] }]
      + (.dns.rules // [])
    )
    | (.outbounds | map(select(.tag == "main-out" and .type == "vless")) | .[0]) as $tpl
    | if $tpl == null then . else
        .outbounds = (
          (.outbounds | map(select(.tag != "main-out" or .type != "vless")))
          + [
              ($tpl | .tag = "cf-a-out" | .server = $cf_a),
              ($tpl | .tag = "cf-b-out" | .server = $cf_b),
              {
                type: "urltest",
                tag: "cf-urltest-out",
                outbounds: ["cf-a-out", "cf-b-out"],
                url: "https://www.gstatic.com/generate_204",
                interval: "30s",
                tolerance: 80
              },
              {
                type: "selector",
                tag: "main-out",
                outbounds: ["cf-urltest-out", "cf-a-out", "cf-b-out"],
                default: "cf-urltest-out"
              }
            ]
        )
      end
  ' "$CFG" > /tmp/sb.tuned.json || exit 1
  sing-box check -c /tmp/sb.tuned.json >/dev/null 2>&1 || exit 1
  cp /tmp/sb.tuned.json "$CFG"
  cp "$CFG" "$OK" 2>/dev/null || true
  logger -t podkop-mgts-tune "applied CF fast path + urltest"
) 9>"$LOCK"

if pidof sing-box >/dev/null 2>&1; then
  sing-box check -c "$CFG" >/dev/null 2>&1 || exit 0
  kill "$(pidof sing-box)" 2>/dev/null
  sleep 1
  sing-box run -c "$CFG" -D /usr/share/sing-box >/dev/null 2>&1 &
  sleep 2
  /usr/bin/podkop-tun-up >/dev/null 2>&1 || true
fi