# SharpVpn Ops Bot (`vpn-bot`)

Telegram bot on FI VPS: `/status`, `/reboot`, `/torrent` (bittorrent cut on/off) + torrent alerts.

## Deploy path

- Host: `193.124.224.248`
- Dir: `/opt/vpn-bot`
- Compose: `docker compose up -d --force-recreate`

## Required env (`/opt/vpn-bot/.env`)

```
BOT_TOKEN=...
ALLOWED_CHAT_IDS=...
REMNAWAVE_BASE_URL=https://vpn2.sharpmaind.ru
REMNAWAVE_API_TOKEN=...
REMNAWAVE_NODE_UUID=...
REMNAWAVE_PLUGIN_UUID=...     # kept OFF (IP-ban forbidden)
REMNAWAVE_PROFILE_UUID=...
TORRENT_ACCESS_LOG=/var/log/remnanode/access.log
TORRENT_ALERT_POLL_SEC=15
TORRENT_ALERT_COOLDOWN_SEC=300
TORRENT_ALERT_STATE_FILE=/app/data/torrent_alerts_state.json
```

Do not commit real tokens.

## Policy

- **Cut only**, no IP ban, no user disable.
- `/torrent` ON → Xray rule `bittorrent → TORRENT_CUT` (+ access log).
- Remnawave Torrent Blocker **plugin stays OFF**.
- Alerts: bot tails `/var/log/remnanode/access.log` for `TORRENT_CUT`, resolves `email` (= user id) via Remnawave API, sends report to `ALLOWED_CHAT_IDS` (cooldown per user).
