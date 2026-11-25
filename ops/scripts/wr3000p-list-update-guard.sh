#!/bin/sh
# WR3000P: обёртка над ежедневным podkop list_update — после обновления не плывёт нода/DNS.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
logger -t wr-lu-guard "list_update start"
timeout 120 /usr/bin/podkop list_update >/tmp/wr-list-update.log 2>&1 || true
sleep 3

[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up
[ -x /usr/bin/podkop-tg-pick.sh ] && /usr/bin/podkop-tg-pick.sh
PIN=$(cat /root/kotikey-pinned-main-out 2>/dev/null)
[ -n "$PIN" ] && [ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN"
[ -x /usr/bin/wr3000p-hdrezka-kotikey.sh ] && /usr/bin/wr3000p-hdrezka-kotikey.sh >/dev/null 2>&1
[ -x /usr/bin/wr3000p-hdrezka-video-vpn.sh ] && /usr/bin/wr3000p-hdrezka-video-vpn.sh >/dev/null 2>&1
[ -x /usr/bin/tv-yt-policy ] && /usr/bin/tv-yt-policy

logger -t wr-lu-guard "list_update done pin=$(cat /root/kotikey-pinned-main-out 2>/dev/null)"
exit 0