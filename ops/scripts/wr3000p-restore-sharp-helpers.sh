#!/bin/sh
# WR3000P: install TV/route helpers from SharpVPN bundle (no FI proxy links).
# Usage: run on router after copying tv-yt-policy, podkop-yt-routes, wr-helper to /tmp/sharp/
set -e
SRC="${1:-/tmp/sharp}"
for f in tv-yt-policy podkop-yt-routes wr-helper; do
	[ -f "$SRC/$f" ] || { echo "missing $SRC/$f"; exit 1; }
	cp -a "$SRC/$f" "/usr/bin/$f"
	chmod +x "/usr/bin/$f"
done
[ -x /usr/bin/wr-helper ] && /usr/bin/wr-helper tv-policy 2>/dev/null || true
echo "sharp helpers installed"