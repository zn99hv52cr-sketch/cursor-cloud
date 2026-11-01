# Telemt MTProxy + Panel (FI VPS)

- **Proxy:** `185.141.217.43:8443` (Fake-TLS, SNI `cloudflare.com`)
- **Panel:** https://vpn2.sharpmaind.ru/mtpanel/ (creds in `/root/creds/mtproxy.txt` on VPS)
- **Services:** `telemt.service`, `telemt-panel.service`
- **Config:** `/etc/telemt/telemt.toml`, `/etc/telemt-panel/config.toml`
- **Client links host:** `public_host` in `telemt.toml` must be the RU-reachable AdminVPS extra IP (`185.141.217.43`). Primary `193.124.224.248` is blackholed from RU — do not advertise it.
- Does **not** use 443 / Remnawave / AWG ports

## 2026-10-04 IP cutover

- Updated `[general.links] public_host` → `185.141.217.43`, restarted `telemt`.
- Panel/API `tg://proxy?server=…` links now use the new IP (verified via `http://127.0.0.1:9091/v1/users`).
- Creds file `/root/creds/mtproxy.txt` link examples updated to match.
