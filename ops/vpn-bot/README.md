# SharpVpn Ops Bot (`vpn-bot`)

Telegram bot on FI VPS: `/status`, `/reboot`, `/torrent` (torrent policy info).

## Deploy path

- Host: `193.124.224.248`
- Dir: `/opt/vpn-bot`
- Compose: `docker compose up -d --build` (or restart after mounting `bot.py`)

## Required env (`/opt/vpn-bot/.env`)

```
BOT_TOKEN=...
ALLOWED_CHAT_IDS=...
REMNAWAVE_BASE_URL=https://vpn2.sharpmaind.ru
REMNAWAVE_API_TOKEN=...          # panel API token (scopes *)
REMNAWAVE_PLUGIN_UUID=...        # node plugin uuid
REMNAWAVE_NODE_UUID=...          # FI node uuid
REMNAWAVE_BLOCK_DURATION=3600
```

Do not commit real tokens.

## Torrent policy

Desired mode: **cut bittorrent only**, no temporary IP ban and no user disable.

- Done in Xray config profile: routing rule `protocol: bittorrent` → outbound `BLOCK` (blackhole), with sniffing enabled.
- Remnawave **Torrent Blocker plugin stays OFF** — that plugin always adds nftables IP ban for `blockDuration`.
- `/torrent` is informational; bot will not turn IP-ban ON. It can only turn the plugin OFF if it was enabled elsewhere.
