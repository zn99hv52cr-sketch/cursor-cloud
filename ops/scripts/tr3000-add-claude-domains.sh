#!/bin/sh
# Run on Cudy TR3000 / WR3000P (OpenWrt + podkop). Adds Claude / Anthropic to split-tunnel list.
set -e

DOMAINS="
claude.ai
anthropic.com
api.anthropic.com
assets-proxy.anthropic.com
s-cdn.anthropic.com
claudeusercontent.com
platform.claude.com
console.anthropic.com
"

for d in $DOMAINS; do
	uci get podkop.main.user_domains 2>/dev/null | tr ' ' '\n' | grep -qx "$d" && continue
	uci add_list podkop.main.user_domains="$d"
done

uci commit podkop
/etc/init.d/podkop restart
sleep 4

if logread 2>/dev/null | tail -30 | grep -qi 'configuration is unchanged'; then
	/etc/init.d/sing-box restart
fi

echo "=== DNS check (198.18.x.x = tunnel) ==="
DNS_SERVER="127.0.0.42"
for d in claude.ai api.anthropic.com assets-proxy.anthropic.com; do
	echo "-- $d"
	nslookup "$d" "$DNS_SERVER" 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print; exit}'
done

echo "=== list (claude/anthropic) ==="
uci get podkop.main.user_domains | tr ' ' '\n' | grep -iE 'claude|anthropic' | sort -u
