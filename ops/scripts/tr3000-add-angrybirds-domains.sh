#!/bin/sh
# OpenWrt + podkop (Cudy TR3000 / WR3000P): steer Angry Birds 2 + Rovio SDK traffic into VLESS tunnel.
# Run on router: sh tr3000-add-angrybirds-domains.sh
# Or from PC: tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-angrybirds-domains.sh
set -e

DOMAINS="
rovio.com
cloud.rovio.com
cdn.rovio.com
rovio-cdn.net
rovio-static.com
helpshift.com
unity3d.com
unity.com
googleapis.com
gstatic.com
fundingchoicesmessages.google.com
applovin.com
applvn.com
vungle.com
mintegral.net
rayjump.com
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

echo "=== DNS (FakeIP 198.18.x.x on TR3000, 198.20.x.x on WR3000P) ==="
for d in cloud.rovio.com cdn.rovio.com rovio.com unity3d.com; do
	echo "-- $d"
	nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print; exit}'
done

echo "=== rovio/unity in user_domains ==="
uci get podkop.main.user_domains | tr ' ' '\n' | grep -iE 'rovio|unity|helpshift|applov|vungle|mintegral|rayjump|fundingchoices' | sort -u
