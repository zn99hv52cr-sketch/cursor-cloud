# FI VPS outage — AWG panel + Telegram bot (2026-11-21)

## Symptoms

- `https://awg.sharpmaind.ru/` — timeout from RU and from Cloud Agent
- `@Vpn_Sharpmaind_bot` — no reply to `/status`, `/torrent`, etc.
- Optional: MTProxy `193.124.224.248:8443` / Remnawave `vpn2` also down (same host)

## What we checked

| Check | Result |
|-------|--------|
| DNS `awg` / `vpn2` | `89.125.57.161` (by design — secondary IP + HAProxy SNI; see `ops/fi-ip-161-haproxy.md`) |
| DNS `home.sharpmaind.ru` | Cloudflare anycast (separate entry path) |
| TCP `22` on `193.124.224.248` | No SSH (timeout / filtered) |
| HTTPS direct to `89.125.57.161` / `185.141.217.43` / `193.124.224.248` | Connect stalls; no HTTP response |
| WR3000P (Tailscale) → same URLs | Same timeouts |
| AdminVPS public site `my.adminvps.ru` | Up (302) |

**Conclusion:** the Finland VM (or its network path) is down or wedged. The bot and Caddy/HAProxy live on that VM, so both panel and bot fail together. This is not a Telegram-token or DNS-only issue while the host is unreachable.

Public reports on 2026-11-21 also mention **AdminVPS Finland** VPS not answering SSH.

## AdminVPS console: use HTML VNC (not Java)

The panel button **«Консоль»** often opens **Java VNC**. Modern browsers (Chrome, Edge, Yandex, Firefox) **do not run Java applets** — installing Java on Windows does **not** fix «нужен Java-плагин».

1. Click **«Консоль»** → in the popup toolbar switch **Java VNC** → **HTML VNC** (noVNC in the browser).
2. Allow the popup for `my.adminvps.ru` if the window is blank.
3. If HTML VNC is black: wait 30–60s after reboot, or try another browser (Firefox sometimes works when Yandex blocks canvas).
4. **Qemu Агент: Доступен** in the panel means the VM is running at the hypervisor; external SSH/HTTPS can still be dead while the guest is up (node/network outage).

## Recovery (requires AdminVPS panel or VNC)

1. Log in: [my.adminvps.ru](https://my.adminvps.ru/) → server **193.124.224.248** (sharpmaind).
2. If status is **offline** or **network error** → **hard reboot** (or ticket to support with “Finland VPS no SSH/HTTPS since …”).
3. After boot, from your PC (not MGTS-only if SSH is filtered, use LTE or another VPN):

```bash
ssh root@193.124.224.248
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Expect at least: **caddy**, **vpn-bot**, **amnezia-awg***, **remnanode**, **haproxy** (if installed on host).

4. If containers are **Exited**:

```bash
cd /opt/vpn-bot && docker compose up -d
# Caddy / Remnawave / AWG stacks — paths on VPS:
# /root/node1, /opt/amnezia, system haproxy
systemctl status haproxy caddy 2>/dev/null || true
```

5. Quick health:

```bash
curl -4 -m 10 -sS -o /dev/null -w '%{http_code}\n' https://awg.sharpmaind.ru/
curl -4 -m 10 -sS -o /dev/null -w '%{http_code}\n' https://vpn2.sharpmaind.ru/
```

6. Bot: send `/status` to `@Vpn_Sharpmaind_bot` from allowed chat. Logs:

```bash
docker logs --tail 80 vpn-bot
```

## Do **not** “fix” by random DNS changes

- `awg` / `vpn2` → `89.125.57.161` is intentional (HAProxy SNI on secondary IP for RU ISPs).
- Moving them to grey-cloud or wrong IP without HAProxy breaks AWG/Remnawave paths documented in `ops/fi-ip-161-haproxy.md`.
- While the VM is down, only **bringing the VM back** (or failover) helps.

## After recovery

- Confirm AWG UDP `89.125.57.161:51820` in client `.conf` (not legacy `185.141.217.43`).
- Caddy must stay **HTTP/2 only** (no HTTP/3 `alt-svc` on UDP/443 — breaks panels).

## Cloud Agent limits

This environment cannot open SSH to `193.124.224.248` when the host is black-holed. Use AdminVPS console or SSH from your network after reboot.