#!/bin/sh
# Send TR3000 handoff text to Telegram. Run where BOT_TOKEN is set (FI VPS: /opt/vpn-bot/.env).
# Usage: CHAT_ID=186409737 ./send-tr3000-handoff-telegram.sh
# Or:    source /opt/vpn-bot/.env && CHAT_ID=186409737 $0
set -e
REPO_BRANCH="${REPO_BRANCH:-cursor/fi-vps-outage-runbook-dead}"
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/${REPO_BRANCH}/ops"
HANDOFF="$BASE/TR3000-FULL-HANDOFF-LOCAL-AGENT.md"

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-186409737}"
if [ -z "$BOT_TOKEN" ] && [ -f /opt/vpn-bot/.env ]; then
	# shellcheck disable=SC1091
	. /opt/vpn-bot/.env
fi
[ -n "$BOT_TOKEN" ] || { echo "Set BOT_TOKEN or run on FI VPS with /opt/vpn-bot/.env"; exit 1; }

TMP="$(mktemp)"
curl -fsSL "$HANDOFF" -o "$TMP"
wc -c "$TMP"

curl -fsS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
	--data-urlencode "chat_id=${CHAT_ID}" \
	--data-urlencode "text=TR3000 handoff + backup instructions (файл следом).
Репо: zn99hv52cr-sketch/cursor-cloud
Ветка: ${REPO_BRANCH}
Raw: ${HANDOFF}" >/dev/null

curl -fsS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
	-F "chat_id=${CHAT_ID}" \
	-F "document=@${TMP};filename=TR3000-FULL-HANDOFF-LOCAL-AGENT.md" >/dev/null

echo "Sent document to chat $CHAT_ID"
rm -f "$TMP"