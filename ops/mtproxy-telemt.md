# Telemt MTProxy + Panel (FI VPS)

- **Proxy:** `193.124.224.248:8443` (Fake-TLS, SNI `cloudflare.com`)
- **Panel:** https://vpn2.sharpmaind.ru/mtpanel/ (creds in `/root/creds/mtproxy.txt` on VPS)
- **Services:** `telemt.service`, `telemt-panel.service`
- **Config:** `/etc/telemt/telemt.toml`, `/etc/telemt-panel/config.toml`
- Does **not** use 443 / Remnawave / AWG ports
