#!/bin/sh
# Run on Cudy TR3000 / WR3000P (OpenWrt + podkop). Adds ChatGPT/OpenAI to split-tunnel list.
set -e

DOMAINS="
chatgpt.com
openai.com
chat.openai.com
api.openai.com
auth.openai.com
platform.openai.com
oaistatic.com
oaiusercontent.com
ab.chatgpt.com
ws.chatgpt.com
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
for d in chatgpt.com openai.com api.openai.com; do
	echo "-- $d"
	nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print; exit}'
done

echo "=== list (openai/chatgpt) ==="
uci get podkop.main.user_domains | tr ' ' '\n' | grep -iE 'openai|chatgpt' | sort -u
