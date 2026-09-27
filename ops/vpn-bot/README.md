# SharpVpn Ops Bot (`vpn-bot`)

Telegram bot on FI VPS: `/status`, `/reboot`, `/torrent` (Remnawave Torrent Blocker on/off).

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

## `/torrent`

Shows current Torrent Blocker state with inline **Включить / Выключить**.
Toggle flow: `PATCH /api/node-plugins/` → `POST .../actions/sync` → soft node restart.
