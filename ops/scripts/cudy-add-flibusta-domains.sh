#!/bin/sh
# Run on Cudy TR3000 / WR3000P (OpenWrt + podkop). Route Flibusta via split tunnel.
set -e

DOMAINS="
flibusta.su
www.flibusta.su
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
for d in flibusta.su www.flibusta.su; do
	echo "-- $d"
	nslookup "$d" "$DNS_SERVER" 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print; exit}'
done

echo "=== list (flibusta) ==="
uci get podkop.main.user_domains | tr ' ' '\n' | grep -i flibusta | sort -u
