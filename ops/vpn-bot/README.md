# SharpVpn Ops Bot (`vpn-bot`)

Telegram bot on FI VPS: `/status`, `/reboot`, `/torrent` (bittorrent cut on/off).

## Deploy path

- Host: `193.124.224.248`
- Dir: `/opt/vpn-bot`
- Compose: `docker compose up -d --build` (or restart after mounting `bot.py`)

## Required env (`/opt/vpn-bot/.env`)

```
BOT_TOKEN=...
ALLOWED_CHAT_IDS=...
REMNAWAVE_BASE_URL=https://vpn2.sharpmaind.ru
REMNAWAVE_API_TOKEN=...
REMNAWAVE_NODE_UUID=...
REMNAWAVE_PLUGIN_UUID=...     # optional; kept OFF (IP-ban)
REMNAWAVE_PROFILE_UUID=...    # optional; auto from node if empty
```

Do not commit real tokens.

## `/torrent`

Inline **Включить срез / Выключить срез**:
- ON → adds Xray routing rule `protocol: bittorrent` → `BLOCK`
- OFF → removes that rule
- Soft-restarts the FI node
- Does **not** enable Remnawave IP-ban plugin
