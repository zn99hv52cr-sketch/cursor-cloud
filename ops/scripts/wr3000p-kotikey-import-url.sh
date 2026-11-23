#!/bin/sh
# Import KotiKey subscription URL into podkop on WR3000P.
# KotiKey often returns "App not supported" for wget/curl — then paste links from Happ.
# Usage: wr3000p-kotikey-import-url.sh 'https://connect.kotikey.pro/TOKEN'
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
URL="${1:-}"
DIR=/root/koty-k-kotikey
LINKS="$DIR/urltest-preferred.links"
IP=46.243.235.234
mkdir -p "$DIR"

[ -n "$URL" ] || { echo "Usage: $0 <subscription-url>"; exit 1; }

fetch() {
	UA="$1"
	curl -4 -k -m30 -A "$UA" \
		--resolve "connect.kotikey.pro:443:${IP}" \
		"$URL" 2>/dev/null
}

for UA in "Happ/3.5.0 (iPhone)" "Happ/3.5" "v2rayNG/1.8.29" "ClashMeta"; do
	RAW="$(fetch "$UA" || true)"
	[ -n "$RAW" ] || continue
	echo "$RAW" > /tmp/koti.b64
	DEC="$(base64 -d /tmp/koti.b64 2>/dev/null || echo "$RAW")"
	echo "$DEC" | grep -q '^vless://' || continue
	echo "$DEC" | grep -q 'App%20not%20supported' && continue
	printf '%s\n' "$DEC" > "$LINKS"
	echo "OK fetched ($UA) -> $LINKS"
	/usr/bin/wr3000p-restore-kotikey.sh
	exit 0
done

echo "FETCH_FAILED: KotiKey отдаёт «App not supported» на curl/wget."
echo "С iPhone в Happ: подписка по URL → все ноды → скопировать ссылки."
echo "На WR: nano $LINKS  (по одной vless:// на строку)"
echo "Затем: /usr/bin/wr3000p-restore-kotikey.sh"
exit 1