#!/bin/sh
# TR3000 MiTV: search/catalog posters via VPN; voidboost/video stays direct.
set -e

POSTER_DOMAINS="st.hdrezka.ac static.hdrezka.ac statichdrezka.ac i.postimg.cc postimg.cc postimg.top image.tmdb.org hdrezka-home.tv"

for d in $POSTER_DOMAINS; do
  while uci del_list podkop.hdrezka_direct.user_domains="$d" 2>/dev/null; do :; done
  uci add_list podkop.main.user_domains="$d" 2>/dev/null || true
done

for c in 179.43.0.0/16 195.154.239.0/24 82.221.0.0/16 185.231.220.9/32; do
  if ! uci get podkop.main.user_subnets 2>/dev/null | tr " " "\n" | grep -Fx "$c" >/dev/null; then
    uci add_list podkop.main.user_subnets="$c"
  fi
done

uci commit podkop
/etc/init.d/podkop restart
sleep 8
rm -f /tmp/sing-box/cache.db
killall -HUP dnsmasq 2>/dev/null || true
echo "posters: main VPN + subnets; voidboost still in hdrezka_direct"