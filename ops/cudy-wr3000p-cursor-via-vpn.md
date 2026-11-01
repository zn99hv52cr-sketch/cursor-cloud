# Cudy WR3000P: Cursor Agent HTTP 403

2026-10-16. PC on WR3000P LAN (`192.168.1.1`) opened Cursor and got `[permission_denied] HTTP 403` immediately. Same account on several machines is allowed; Cloud Agent is not a second device. The 403 was routing, not the license.

## Cause

Podkop FakeIP already mapped `api2.cursor.sh` to `198.20.x`, but `/usr/bin/podkop-tun-up` prepended:

```
domain_suffix: cursor.sh, cursorapi.com, cursor.com → direct-out
domain_keyword: cursor.sh → direct-out
```

Those rules sat above the main proxy match, so Cursor API left via Rostelecom. Cursor then answers 403 for some RU client IPs. `cursor.com` was also missing from `podkop.main.user_domains`, so it resolved to a real Vercel address instead of FakeIP.

TR3000 already had `cursor.com` / `cursor.sh` / `cursor-cdn.com` / `cursorapi.com` / `cursorvm.com` in the tunnel list and did **not** force them direct.

Same class of bug as Keenetic Air (`ops/keenetic-air-split-tunnel.md`): Cursor must egress from FI, not from the ISP.

## Applied on WR3000P

- Backup: `/usr/bin/podkop-tun-up.bak-cursor-direct-20261016`
- Removed Cursor `direct-out` rules from `podkop-tun-up`. Fast-path no longer skips while those leftovers exist.
- `uci add_list podkop.main.user_domains`: `cursor.com`, `cursor.sh`, `cursor-cdn.com`, `cursorapi.com`, `cursorvm.com` (suffix match covers `api2` / `api3` / `authenticator`)
- `user_subnets` + `sbtun` routes: `76.76.0.0/16`, `66.33.60.0/23` (Vercel / www.cursor.com when the app skips router DNS)
- Helpers listed in `/etc/sysupgrade.conf` so a firmware upgrade does not drop them

VLESS stays WebSocket `/vpn`. Do not put Cursor back on `direct-out`.

## Check

From the router:

```sh
nslookup api2.cursor.sh 192.168.1.1   # 198.20.…
nslookup cursor.com 192.168.1.1       # 198.20.…
# route rules: zero cursor → direct-out
curl -4 -sSI --max-time 15 https://api2.cursor.sh/ | head
# cursor.com Set-Cookie logoCountry=FI
# authenticator CF-RAY …-HEL
```

Verified 2026-10-16: `api2` HTTP 200 (envoy), `cursor.com` `logoCountry=FI`, authenticator `cf-ray …-HEL`, Instagram/Telegram/YouTube HTTP 200.

On the PC: DNS `192.168.1.1`, no Happ/system proxy, no Secure DNS. Restart Cursor, then Try again in the failed chat (or open https://cursor.com/agents/ and continue there).
