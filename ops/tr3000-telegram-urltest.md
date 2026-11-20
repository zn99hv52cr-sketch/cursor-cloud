# TR3000 — Telegram через urltest

МГТС **режет** `149.154.x` напрямую. Telegram обязан идти в VLESS.

`urltest` часто выбирает ноду, которая **blackhole** DC Telegram (на проверке 2026-11-20 жила только `main-1-out`). Остальные — timeout. Отсюда «ТГ не грузит», при этом YouTube жив.

Нельзя чинить это `podkop restart` по cron (`curl web.telegram.org || restart`) — рестарт роняет nft/маршруты.

На роутере: `/usr/bin/podkop-tg-pick.sh` перебирает `main-N-out`, пока `https://web.telegram.org/` не ответит. Вызов из `podkop-tun-up` и cron `*/20`.
