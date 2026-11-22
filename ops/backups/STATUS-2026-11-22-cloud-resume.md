# Cloud resume after dead run (22 Nov 2026, MSK evening)

Source: uploaded zip / branch `cursor/fi-vps-outage-runbook-dead`, PR [#54](https://github.com/zn99hv52cr-sketch/cursor-cloud/pull/54).

## FI Finland VPS (`193.124.224.248`)

- **AWG / vpn2 HTTPS:** up (401 basic auth) — not the 21 Nov blackout.
- **ICMP:** filtered/down from cloud; do not use ping alone as health.
- **SSH from cloud:** blocked without `SSHPASS` / key; use your PC or AdminVPS HTML VNC per `ops/sharpmaind-fi-outage.md`.

## TR3000 (`100.81.160.52`, dropbear `:2222`)

| Item | After resume |
|------|----------------|
| Cloud → TR SSH | **Works** with `CUDY_TR3000_SSH_KEY` written to `~/.ssh/wr3000p_ed25519` (install hook) |
| `tr3000-boot-stable.sh` | Ran on router: **ig=200**, sing-box up, fakeip DNS ok |
| `tr3000-hdrezka-mitv-apply.sh` | Ran: MiTV `192.168.2.145` fakeip route via `sbtun`, mangle rules present |
| Tailscale GUI status | May show **offline** while ping/SSH work (stale UI) |

## Still open (needs LAN / your phone / FI SSH)

1. **iPhone on home Wi‑Fi** — instagram/ blocked sites (see `tr3000-ios-wifi-*.sh`).
2. **MiTV HDrezka posters in search UI** — confirm on the TV after apply.
3. **USB backup → Telegram** — run `tr3000-export-usb-backup.sh` on TR, then `tr3000-send-backup-telegram.sh` on FI VPS with bot token.
4. **Clash API `:9090`** — was down during checks; `main-5-out` pin in boot-stable is best-effort until API listens.

## Cloud agent fix in repo

`ops/scripts/cloud-agent-env-install.sh` materializes inline `CUDY_TR3000_SSH_KEY` so `ssh -i ~/.ssh/wr3000p_ed25519 -p 2222 root@100.81.160.52` works on fresh VMs.