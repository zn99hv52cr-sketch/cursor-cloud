# Local Cursor handoff — FI VPN / torrent cut / SharpVpnBot

Use this file in **Cursor Desktop (local)**, not Cloud Agent.
Open repo `zn99hv52cr-sketch/cursor-cloud`, start a new Agent/Composer chat, attach this file (`@ops/LOCAL-CHAT-HANDOFF.md`) and continue from here.

Cloud run (source of this context): https://cursor.com/agents/bc-6545d4f3-20f6-4810-a2ce-c767c0bddead  
PR: https://github.com/zn99hv52cr-sketch/cursor-cloud/pull/5  
Branch: `cursor/vpn-bot-torrent-toggle-dead` (base: `master`)

---

## What the user wants (policy)

1. **Cut BitTorrent traffic** through the VPN (blackhole), **without** banning user accounts and **without** temporary IP bans (nftables).
2. **Telegram on/off** for that cut in `@Vpn_sharpmaind_bot` (`SharpVpnBot`).
3. **Telegram alerts** when someone hits the cut: who (username/id), inbound, dest, short report.
4. AdminVPS ToS: torrent clients/trackers without approval are forbidden; abuse → 24h fix / block / disconnect without refund. Cutting torrents on FI VPS is intentional risk reduction.

**Do not** enable Remnawave **Torrent Blocker** plugin for production alerts — it always IP-bans via nftables for `blockDuration`.

---

## Infrastructure (FI VPS)

| Item | Value |
|------|--------|
| Host | `193.124.224.248` (`sharpmaind`); RU clients use extra IP `185.141.217.43` |
| Provider | AdminVPS |
| Panel | https://vpn2.sharpmaind.ru (Remnawave backend **3.x**) |
| Node | `remnanode` image `remnawave/node:3.4.1`, `NET_ADMIN`, host network |
| Node name / UUID | `Fi- Finland` / `50658d10-c581-409c-9cce-5c15982363f1` |
| Config profile | `vless-main` / `7e210495-fa74-47a4-82a0-005e464a8965` |
| Plugin UUID (keep OFF) | `e10fbeef-cb23-459e-820a-d1e7f3add865` |
| Ops bot | `/opt/vpn-bot` container `vpn-bot`, compose project on VPS |
| Bot TG | `@Vpn_sharpmaind_bot`, allowed chat `186409737` |
| Creds on VPS | `/root/creds/` (mtproxy, kuma, remnawave JWT for bot — **do not commit**) |
| SSH | root + `SSHPASS` in cloud env; locally use your own key/password |

Also on same VPS (do not break): AmneziaWG `:51820`, Caddy (`vpn2` / `awg` / `kuma`), Telemt MTProxy `:8443` + `/mtpanel`, Uptime Kuma, Remnawave DB/Redis.

Repo workspace is ops-only: notes + `ops/vpn-bot/` mirror. **Secrets stay on VPS `.env`, never in git.**

---

## How torrent cut + alerts work now

### Cut (no IP ban)

- Xray outbound: `TORRENT_CUT` = `blackhole`
- Routing rule: `protocol: ["bittorrent"]` → `outboundTag: TORRENT_CUT`, `ruleTag: TORRENT_CUT`
- Sniffing on inbounds: `http`, `tls`, `quic` (needed to classify bittorrent)
- Remnawave plugin `torrentBlocker.enabled` = **false**

`/torrent` in the bot:
- **ON** → ensure log paths + `TORRENT_CUT` outbound + add BT rule → soft restart node → ensure plugin OFF
- **OFF** → remove BT→TORRENT_CUT/BLOCK rules → soft restart → ensure plugin OFF

### Alerts (no IP ban)

- Access log: `/var/log/remnanode/access.log` (mounted into `remnanode` and read-only into `vpn-bot`)
- Log line shape:  
  `... accepted tcp:IP:port [vless-main >> TORRENT_CUT] email: <userId>`
- `email` in Xray = Remnawave **numeric user id**
- Bot polls log every ~15s, resolves `GET /api/users/{id}`, sends HTML alert to `ALLOWED_CHAT_IDS`
- Cooldown ~300s per user id; state: `/opt/vpn-bot/data/torrent_alerts_state.json`

**Important:** An early alert for user **Gope (id 12)** was a **synthetic test line** injected into access.log to verify the pipeline — not real torrent use.

### Remnawave API used by bot

Env on VPS `/opt/vpn-bot/.env` (names only):

- `REMNAWAVE_BASE_URL=https://vpn2.sharpmaind.ru`
- `REMNAWAVE_API_TOKEN` (API role JWT, token row name `vpn-bot`)
- `REMNAWAVE_NODE_UUID`, `REMNAWAVE_PLUGIN_UUID`, `REMNAWAVE_PROFILE_UUID`
- `TORRENT_ACCESS_LOG`, `TORRENT_ALERT_*`

Endpoints: nodes, config-profiles PATCH, nodes `.../actions/restart` with `{"forceRestart":false}`, node-plugins GET/PATCH/sync (only to force plugin OFF), users by id.

---

## Code / deploy map

| Path | Role |
|------|------|
| `ops/vpn-bot/bot.py` | Source of truth in git (synced to VPS) |
| `ops/vpn-bot/README.md` | Deploy notes |
| `ops/vpn-bot/.env.example` | Env template without secrets |
| VPS `/opt/vpn-bot/bot.py` | Live (bind-mounted) |
| VPS `/opt/vpn-bot/docker-compose.yml` | host net, privileged, mounts bot.py, data, remnanode logs, docker.sock |
| VPS `/root/node1/docker-compose.yml` | remnanode + `/var/log/remnanode` volume |

Deploy after bot edit:

```bash
scp ops/vpn-bot/bot.py root@193.124.224.248:/opt/vpn-bot/bot.py
ssh root@193.124.224.248 'cd /opt/vpn-bot && docker compose up -d --force-recreate'
```

---

## Live state snapshot (2026-09-28)

- `torrentBlocker` plugin: **OFF**
- Cut rule present: `bittorrent → TORRENT_CUT`
- Outbounds include `DIRECT`, `BLOCK`, `TORRENT_CUT`
- Access logging on
- `vpn-bot` / `remnanode`: up
- access.log growing under `/var/log/remnanode/`

---

## Related ops notes already in repo

- `ops/keenetic-air-split-tunnel.md` — Keenetic Air AWG split-tunnel / CPU
- `ops/mtproxy-telemt.md` — Telemt MTProxy + panel on FI

---

## AdminVPS (torrent ToS, short)

Oferta §13: forbidden without approval — torrent clients/trackers, download clients, file hosts, heavy stream projects, etc. Sanctions: 24h to fix, block until fixed, or disconnect without refund (+ possible costs). VPN explicitly restricted for BY/KZ locations in oferta; FI not listed the same way, but torrent/P2P still forbidden.

---

## Suggested first message in a local chat

> Continue from `@ops/LOCAL-CHAT-HANDOFF.md`. FI VPS Remnawave + SharpVpnBot: bittorrent cut via TORRENT_CUT without IP ban, TG /torrent toggle + access.log alerts. Do not enable Remnawave torrentBlocker plugin. Ask before changing AdminVPS-facing traffic policy or opening new ports.

---

## Open / next ideas (not done unless asked)

- Deduplicate/noise-reduce alerts if false positives appear
- Rotate/truncate huge `access.log` / `error.log` on remnanode
- Panel UI vs bot cut toggle drift checks
- Document restore if profile config is overwritten in panel UI
