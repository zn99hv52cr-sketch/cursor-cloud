#!/bin/sh
# WR3000P: восстановление из LAN (LuCI / SSH), когда агент по Tailscale недоступен.
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

fetch() { curl -fsSL "$BASE/$1" -o "/usr/bin/$2"; chmod +x "/usr/bin/$2"; }

fetch wr3000p-boot-stable.sh wr3000p-boot-stable.sh
fetch wr3000p-stable-apply.sh wr3000p-stable-apply.sh
fetch wr3000p-podkop-tg-pick.sh podkop-tg-pick.sh
fetch wr3000p-pin-main-out.sh wr3000p-pin-main-out.sh
fetch wr3000p-kotikey-lock-selector.sh wr3000p-kotikey-lock-selector.sh
fetch wr3000p-hdrezka-kotikey.sh wr3000p-hdrezka-kotikey.sh
fetch wr3000p-hdrezka-video-vpn.sh wr3000p-hdrezka-video-vpn.sh
fetch wr3000p-podkop-tun-up.sh podkop-tun-up
fetch wr3000p-podkop-route-fix.sh wr3000p-podkop-route-fix.sh
fetch wr3000p-emergency-up.sh wr3000p-emergency-up.sh

if [ -s /overlay/backups/sing-box-config.ok.json ] && [ ! -s /etc/sing-box/config.json ]; then
	cp /overlay/backups/sing-box-config.ok.json /etc/sing-box/config.json
	cp /etc/sing-box/config.json /etc/sing-box/config.json.ok
fi

/usr/bin/wr3000p-boot-stable.sh
/usr/bin/wr3000p-stable-apply.sh
tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null || true
logger -t wr-lan-recover done
exit 0