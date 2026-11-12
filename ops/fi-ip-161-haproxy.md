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

## DNS (reg.ru)

| Name | A record |
|------|----------|
| `vpn2.sharpmaind.ru` | `89.125.57.161` |
| `awg.sharpmaind.ru` | `89.125.57.161` |

## AWG (AmneziaWG)

- UDP listener: Docker `amnezia-awg3` on `0.0.0.0:51820` (both IPs).
- Image pin (2026-11-12): `amnezia-awg2:3.1.20260828` (`FROM amneziavpn/amneziawg-go:3.1.20260828`, tools `v3.1.20260812`). Compatible with AmneziaVPN **5.1** clients (protocol AWG **3.1** — there is no server “5.1”).
- Build context: `/opt/amnezia/amnezia-awg2`. Rollback: start stopped `amnezia-awg3-pre-*` or restore `/root/backups/awg-pre-upgrade-*.tar.gz`.
- Client **Endpoint** must be `89.125.57.161:51820` (many old `.conf` had hardcoded `185.141.217.43:51820` — DNS change alone does nothing).
- Host iptables redirects UDP `443/4500/123/53` → `51820` for camouflage ports.
- **Do not enable Caddy HTTP/3**: `alt-svc: h3` makes browsers switch to QUIC on UDP/443, which is AWG — HTTPS to `awg`/`vpn2` then hangs. Caddyfile must keep `servers { protocols h1 h2 }` (not only `servers :443`, because sites `bind` a specific IP) and strip `Alt-Svc`.

## CF host updater

`/opt/cf-front/update-hosts-to-current-url.sh` must update **only CF hosts**, never wipe `89.125.57.161` addresses.
