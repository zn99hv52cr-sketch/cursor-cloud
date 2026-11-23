#!/bin/sh
# Upload TR3000 backup tarball to Telegram chat. Run on FI VPS (vpn-bot .env) or with BOT_TOKEN set.
# Usage: CHAT_ID=186409737 ./tr3000-send-backup-telegram.sh /path/to/tr3000-backup-*.tar.gz
set -e
FILE="${1:-}"
[ -f "$FILE" ] || { echo "Usage: $0 /path/to/tr3000-backup-....tar.gz"; exit 1; }

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-186409737}"
if [ -z "$BOT_TOKEN" ] && [ -f /opt/vpn-bot/.env ]; then
	# shellcheck disable=SC1091
	. /opt/vpn-bot/.env
fi
[ -n "$BOT_TOKEN" ] || { echo "Set BOT_TOKEN or run on VPS with /opt/vpn-bot/.env"; exit 1; }

SIZE="$(stat -c%s "$FILE" 2>/dev/null || stat -f%z "$FILE")"
if [ "$SIZE" -gt 48000000 ]; then
	echo "File too large for Telegram (>48MB): $SIZE"; exit 1
fi

curl -fsS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
	--data-urlencode "chat_id=${CHAT_ID}" \
	--data-urlencode "text=TR3000 backup (KotiKey + UCI podkop). Restore: tr3000-restore-from-backup.sh" >/dev/null

curl -fsS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
	-F "chat_id=${CHAT_ID}" \
	-F "document=@${FILE}" \
	-F "caption=tr3000-backup KotiKey" >/dev/null

echo "Sent $(basename "$FILE") ($SIZE bytes) to chat $CHAT_ID"