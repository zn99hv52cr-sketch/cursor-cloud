# Beeline vs Megafon on FI VPS (Юля + Эмиль)

См. также: `ops/emil-beeline-troubleshooting.md` — если у Эмиля на Билайне «перестало работать».

## Архитектура пользователей Emil Izmailov

| Логин | Сквад(ы) | Назначение |
|-------|----------|------------|
| `Emil_1`…`Emil_5` | **только `Emil-Beeline`** | Телефоны на **Билайн** — первым **Билайн packet-up** (xHTTP `/xh/`, ALPN `http/1.1`) |
| `Emil_6` | **только `happ`** | Happ Portable — **15 профилей**, первым **Мегафon WS** (для смены оператора, не для Билайна!) |

**Важно:** на SIM **Билайн** подписку **`Emil_6` / сквад `happ` не использовать** как основную — там первым Мегafon, его Билайн режет. Для Билайна — **`Emil_1`…`Emil_5`**.

## Почему на Билайне ломается

- Билайн DPI режет **WebSocket + gRPC (HTTP/2)** и часто **Megafon-профиль** (WS `/vpn`).
- Рабочий транспорт: **xHTTP packet-up**, ALPN **`http/1.1`**, путь **`/xh/`**.
- Inbound `vless-xhttp` на ноде должен быть **`mode=auto`** (принимает packet-up / stream-up / stream-one).
- Если dedicated-хосты «Билайн packet-up*» в панели **`isDisabled=true`**, в подписке остаётся один **WS** — на Билайне «не работает».

## Что должно быть в панели (Emil-Beeline)

Dedicated-хосты **включены**, порядок (`viewPosition`):

1. Билайн packet-up (chrome)
2. Билайн packet-up FF
3. Билайн stream-one
4. Билайн stream-up
5. Билайн WS (firefox, **http/1.1**, без h2)

**Не** отдавать в этот сквад: gRPC, WS с h2, «Megafon- Финляндия» первым.

## Клиент (Happ / v2raytun)

1. Подписка только **`https://vpn2.sharpmaind.ru/api/sub/...`** (не `vpn.sharpmaind.ru`).
2. **Обновить подписку** (pull-to-refresh).
3. Вручную выбрать **«Билайн packet-up»** (не «первый в списке», если там Мегafon).
4. Запасные: **packet-up FF** → **stream-one** → **stream-up** → **WS FF**.

## VPS (политика)

- Не авто-апгрейд Remnawave/node без окна и бэкапа (`/root/creds/upgrade-watch.md`).
- Egress YouTube: `193.124.224.248`.
