#!/bin/sh
# WR3000P: восстановить стабильный KotiKey + HDrezka MiTV (без podkop restart).
PATH=/usr/sbin:/usr/bin:/sbin:/bin
PIN="${KOTIKEY_PIN:-main-4-out}"
printf '%s\n' "$PIN" > /root/kotikey-pinned-main-out

# Автозапуск после ребута (rc.local).
if [ -x /usr/bin/wr3000p-boot-stable.sh ] && [ -f /etc/rc.local ]; then
	grep -q wr3000p-boot-stable /etc/rc.local 2>/dev/null || {
		sed -i '/^exit 0/i /usr/bin/wr3000p-boot-stable.sh \&' /etc/rc.local 2>/dev/null || \
			printf '%s\n' '/usr/bin/wr3000p-boot-stable.sh &' >> /etc/rc.local
	}
fi

# Раз в 10 мин — pin-guard, не каждые 2 мин перебор нод.
CR=/etc/crontabs/root
grep -v podkop-tg-pick "$CR" 2>/dev/null > /tmp/cr.new || : > /tmp/cr.new
grep -q wr3000p-stable-apply /tmp/cr.new || echo '*/10 * * * * /usr/bin/wr3000p-stable-apply.sh quick' >> /tmp/cr.new
mv /tmp/cr.new "$CR"
/etc/init.d/cron enable 2>/dev/null
/etc/init.d/cron restart 2>/dev/null

[ "$1" = quick ] && {
	[ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN"
	/usr/bin/podkop-tg-pick.sh 2>/dev/null || true
	logger -t wr-stable "quick pin=$PIN"
	exit 0
}

[ "$1" = quick ] || {
	[ -x /usr/bin/wr3000p-kotikey-lock-selector.sh ] && /usr/bin/wr3000p-kotikey-lock-selector.sh
	[ -x /usr/bin/wr3000p-hdrezka-kotikey.sh ] && /usr/bin/wr3000p-hdrezka-kotikey.sh
	[ -x /usr/bin/wr3000p-hdrezka-video-vpn.sh ] && /usr/bin/wr3000p-hdrezka-video-vpn.sh
}

[ -x /usr/bin/wr3000p-pin-main-out.sh ] && /usr/bin/wr3000p-pin-main-out.sh "$PIN"
/usr/bin/podkop-tg-pick.sh 2>/dev/null || true
[ -x /usr/bin/podkop-tun-up ] && /usr/bin/podkop-tun-up 2>/dev/null || true
[ -x /usr/bin/tv-yt-policy ] && /usr/bin/tv-yt-policy 2>/dev/null || true
logger -t wr-stable "ok pin=$PIN"
exit 0