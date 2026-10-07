# Emil Beeline squad

Пользователя `Emil_Izmailov` в Remnawave нет. Мобильный Билайн — это шесть активных подписок `Emil_1` … `Emil_6` (id 40, 42, 43, 44, 45, 98).

## Что было не так

Они сидели в `Default-Squad`. В Remnawave 3.4 связь хоста со сквадом в режиме `EXCLUDE` прячет хост от этого сквада. Участники Default видят только 15 хостов, которые из Default не исключены: в начале списка Мегафон (WS / gRPC / xHTTP stream-up), не Билайн.

По access-логу ноды за 27 сентября — 7 октября 2026 эти подписки ходили только в `vless-grpc` и `vless-main`. `vless-xhttp` не использовался.

Серверный inbound `vless-xhttp` был в режиме `stream-one`. Такой сервер принимает только `stream-one`. Профили `packet-up` и `stream-up` до клиента доходили, но сессия не поднималась. Для мобильного Билайна как раз нужен `packet-up` по HTTP/1.1: gRPC и WebSocket с h2 режутся и тормозят.

## Что сделано 2026-10-07

1. Inbound `vless-xhttp` переведён с `stream-one` на `auto`. Сервер принимает `packet-up`, `stream-up` и `stream-one`. Старые клиенты со `stream-one` остаются рабочими. Бэкап конфига: `/root/backups/vless-main-config-20261007T072759Z.json`. Xray на ноде перечитал конфиг в 07:28 UTC.
2. Сквад `Emil-Beeline` (`b942ddbc-1bc9-41b2-b5ce-10c266b0516d`) с инбаундами `vless-xhttp`, `vless-main`, `vless-grpc`.
3. Шесть хостов только для этого сквада (`ALLOW_ONLY`), адрес `185.141.217.43:443`, SNI `vpn2.sharpmaind.ru`:
   - Билайн packet-up — xHTTP, ALPN `http/1.1`, fingerprint chrome
   - Билайн packet-up FF — то же, firefox
   - Билайн stream-one — запасной xHTTP
   - Билайн stream-up — запасной xHTTP
   - Билайн WS и Билайн WS FF — WebSocket только `http/1.1`, без h2 и без gRPC
4. `Emil_1` … `Emil_6` сняты с `Default-Squad` и переведены в `Emil-Beeline`.
5. Остальные хосты (режим `EXCLUDE`) исключены из `Emil-Beeline`, иначе пустой сквад видит все хосты панели.

Проверка подписки `v2raytun/android` для всех шести: ровно 6 профилей, первый — `Билайн packet-up`. У контрольного пользователя Default-Squad по-прежнему 15 профилей.

На хостах packet-up в `extra` заданы `xPaddingBytes` `100-1000`, `scMaxEachPostBytes` `200000-500000`, `scMinPostsIntervalMs` `10-40`.

## Что сделать на телефонах

В v2raytun или Happ обновить подписку и выбрать **Билайн packet-up**. Если не цепляется — `Билайн packet-up FF`, затем `stream-one`. Старые профили Мегафона и gRPC из подписки ушли, пока приложение не обновит подписку, оно будет пытаться ходить старым кэшем.
