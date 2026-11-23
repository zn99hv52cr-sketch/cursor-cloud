#!/bin/sh
# TR3000: MiTV HDrezka poster CDNs → hdrezka_direct (direct). Does not touch voidboost/video.
set -e
for d in \
  i.postimg.cc postimg.cc postimg.top \
  static.hdrezka.ac statichdrezka.ac st.hdrezka.ac \
  hdrezka-home.tv hdrzk.org image.tmdb.org; do
  uci add_list podkop.hdrezka_direct.user_domains="$d" 2>/dev/null || true
done
uci commit podkop
/etc/init.d/podkop restart
sleep 5
rm -f /tmp/sing-box/cache.db
killall -HUP dnsmasq 2>/dev/null || true
echo "hdrezka poster domains added; voidboost unchanged"