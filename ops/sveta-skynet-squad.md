# Sveta, Скайнет, Петербург

Пользователь `Sveta` (id 5) сидела в `Default-Squad`. Подписка начиналась с `🇫🇮 Megafon- Финляндия` — WebSocket. По логу ноды она ходила только в `vless-main`, xHTTP не использовала. Клиент: Happ на iPhone 15 Pro Max.

Домашний Wi‑Fi Скайнета режет этот WebSocket. В общем скваде xHTTP был с ALPN `h2`, для Скайнета это тоже плохой первый выбор.

## Что сделано 2026-10-08

Сквад `Sveta-SkyNet` (`b52de567-f64e-4951-94f2-08689b9a3983`). `Sveta` снята с `Default-Squad`.

Шесть хостов только этого сквада, адрес `185.141.217.43:443`, SNI `vpn2.sharpmaind.ru`, без HTTP/2:

1. Скайнет packet-up — xHTTP, ALPN `http/1.1`, chrome
2. Скайнет packet-up FF — то же, firefox
3. Скайнет stream-one
4. Скайнет stream-up
5. Скайнет WS FF — WebSocket, `http/1.1`, firefox
6. Скайнет WS — WebSocket, `http/1.1`, chrome

Остальные хосты из сквада исключены. Проверка подписки Happ: 6 профилей, первый `Скайнет packet-up`. У Default-Squad по-прежнему 15 профилей. Сервер xHTTP в режиме `auto`, `packet-up` он принимает.

На iPhone обновить подписку в Happ и выбрать **Скайнет packet-up**. Если не цепляется — `packet-up FF`, затем `stream-one`.
