#!/bin/sh
# OpenWrt + podkop (TR3000 / WR3000P): Angry Birds 2 — только домены игры/SDK в туннель.
# НЕ трогает fully_routed_ips, НЕ googleapis.com/gstatic.com целиком, НЕ disable_quic.
# Run: tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-angrybirds-domains.sh
set -e

# Снять прошлые «широкие» правки, если остались
uci set podkop.settings.disable_quic='0'
uci set podkop.main.enable_udp_over_tcp='0'
while uci del_list podkop.main.fully_routed_ips='192.168.2.242' 2>/dev/null; do :; done

BROAD="googleapis.com gstatic.com"
for d in $BROAD; do
	while uci del_list podkop.main.user_domains="$d" 2>/dev/null; do :; done
done

DOMAINS="
rovio.com
cloud.rovio.com
cdn.rovio.com
assets-cloud.rovio.com
ab2.rovio.com
api.rovio.com
rovio-cdn.net
rovio-static.com
helpshift.com
rovio.zendesk.com
unity3d.com
unity.com
unityads.unity3d.com
config.unityads.unity3d.com
configv2.unityads.unity3d.com
i-sdk.mediation.unity3d.com
cdp.cloud.unity3d.com
data-optout-service.uca.cloud.unity3d.com
upm.unity.com
packages.unity.com
ads.unity.com
applovin.com
applvn.com
vungle.com
config.ads.vungle.com
mintegral.net
pok.mintegral.net
rayjump.com
configure.rayjump.com
policy.rayjump.com
lazy.rayjump.com
check.rayjump.com
fundingchoicesmessages.google.com
play.googleapis.com
play-fe.googleapis.com
android.googleapis.com
firebase.googleapis.com
firebaseinstallations.googleapis.com
firebaselogging.googleapis.com
firebaselogging-pa.googleapis.com
gmscompliance-pa.googleapis.com
connectivitycheck.gstatic.com
www.gstatic.com
sentry.io
"

for d in $DOMAINS; do
	uci get podkop.main.user_domains 2>/dev/null | tr ' ' '\n' | grep -qx "$d" && continue
	uci add_list podkop.main.user_domains="$d"
done

uci commit podkop
/etc/init.d/podkop restart
sleep 5
if logread 2>/dev/null | tail -30 | grep -qi 'configuration is unchanged'; then
	/etc/init.d/sing-box restart
fi
sleep 2
/usr/bin/podkop-tun-up 2>/dev/null || true

echo "=== sanity (must stay tunnel FakeIP 198.18/198.20) ==="
for d in rutracker.org voidcrystal.org cloud.rovio.com cdn.rovio.com; do
	a=$(nslookup "$d" 127.0.0.1 2>/dev/null | awk '/^Address: / && $2 !~ /127\\./ {print $2; exit}')
	echo "$d -> ${a:-FAIL}"
done
echo "disable_quic=$(uci get podkop.settings.disable_quic)"
echo "fully_routed=$(uci get podkop.main.fully_routed_ips 2>/dev/null || echo none)"
