# FI secondary IP `89.125.57.161` — client path (2026-11-12)

When primary `185.141.217.43` is degraded from RU ISPs (many `FIN-WAIT-1` on `:443`), clients use the secondary IP.

## Live layout

| Piece | Role |
|-------|------|
| `89.125.57.161:443` | **HAProxy** TCP SNI mux (`/etc/haproxy/haproxy.cfg`) |
| SNI `vpn2` / `awg` / `kuma` | → Caddy on `185.141.217.43:443` (WS / xHTTP / gRPC / `/api/sub`) |
| Other SNI (Reality / microsoft) | → `127.0.0.1:9443` (`vless-reality-248`) |
| Remnawave hosts | Almost all `address=89.125.57.161` (not `185.141`) |
| Reality inbound | In **every** internal squad |
| CF quick tunnel | `cf-front-tunnel.service` → `/opt/cf-front` (backup WS + sub) |
| `SUB_PUBLIC_DOMAIN` | CF `*.trycloudflare.com/api/sub` (links that work without VPN) |

Do **not** re-add iptables `REDIRECT 161:443 → 9443` — that steals the port from HAProxy. Script: `/opt/remnawave/sveta-reality-161.nat.sh`.

## Client recovery

1. Refresh SharpVpn subscription (🔄).
2. Prefer **`Reality NEW` / `Beeline Reality` / `MTS Reality`** or any node on `89.125.57.161`.
3. If 🔄 to `vpn2.sharpmaind.ru` times out: use CF sub URL from panel/`SUB_PUBLIC_DOMAIN`, or refresh while on another VPN (Fornex).

## DNS (still needed for old sub URLs)

`vpn2.sharpmaind.ru` A is still `185.141.217.43` at **reg.ru**.  
Change A → `89.125.57.161` so existing in-app subscription URLs open without VPN (HAProxy already terminates `vpn2` SNI on 161).

## CF host updater

`/opt/cf-front/update-hosts-to-current-url.sh` must update **only CF hosts**, never wipe `89.125.57.161` addresses.
