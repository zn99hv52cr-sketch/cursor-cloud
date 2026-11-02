# Sveta, Дом.ru, центр Петербурга

Пользователь `Sveta` (id 5, short uuid `RnqwjtrNjArut7LD`). Домашний провайдер **Дом.ru**. Клиент: Happ на iPhone.

| | |
|---|---|
| Сквад | `Sveta-DomRu` (`b52de567-f64e-4951-94f2-08689b9a3983`) |
| Подписка | `https://vpn2.sharpmaind.ru/api/sub/RnqwjtrNjArut7LD` |

## Что выяснилось

- 2053 и `193.124.224.248` с её Wi‑Fi не доходят.
- WS на `185.141.217.43:443` цепляется и через несколько минут DPI рвёт.
- Reality с SNI `www.microsoft.com` на этот IP ни разу не принялся (Happ остаётся на первой строке).
- Caddy на `127.0.0.1:443`, публичный `.43:443` — Reality с fallback на сайт.

## Порядок сейчас

1. **Дом.ru packet-up** — xHTTP `http/1.1` safari, `/xh/`. Автоподключение.
2. **Megafon- Финляндия** — мобильная связь.
3. **Дом.ru packet-up iOS**
4. **Дом.ru Reality** — тот же `.43:443`, SNI уже `vpn2.sharpmaind.ru` (не Microsoft).
5. WS FF / Safari / iOS / WS — запас.

На iPhone потянуть подписку. Дома первая **Дом.ru packet-up**.
