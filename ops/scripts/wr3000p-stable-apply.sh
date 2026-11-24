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

# Cron: antidrift каждые 5 мин; list_update только через guard; без старого tg-pick */2.
CR=/etc/crontabs/root
{
	grep -v -E 'podkop-tg-pick|podkop list_update|wr3000p-stable-apply|wr3000p-antidrift|wr3000p-list-update-guard' "$CR" 2>/dev/null || true
	echo '*/5 * * * * /usr/bin/wr3000p-antidrift.sh'
	echo '13 9 * * * /usr/bin/wr3000p-list-update-guard.sh'
	echo '0 4 * * 0 /usr/bin/wr3000p-stable-apply.sh'
} > /tmp/cr.new
mv /tmp/cr.new "$CR"
/etc/init.d/cron enable 2>/dev/null
/etc/init.d/cron restart 2>/dev/null
rm -f /root/kotikey-allow-failover 2>/dev/null

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