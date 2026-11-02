# Sveta, Дом.ru — только VLESS

Дом.ru DPI: долгий WS на `.43:443` рвёт; Reality `:2053` не доходит; `trycloudflare.com` у неё тоже не зашёл. AWG не используем.

## Сейчас (VLESS)

1. **Дом.ru Reality 2083** — Reality, SNI Microsoft, порт **2083**
2. **Дом.ru Reality 2096** — то же, порт **2096**
3. **Megafon- Финляндия** — WS 443
4. **Дом.ru gRPC** — gRPC 443
5. packet-up / WS / Reality 2053 — запас

CF-профили у Светы скрыты. На ноде Reality 2083/2096 только для сквада `Sveta-DomRu`.

На iPhone потянуть подписку. Первая строка — **Дом.ru Reality 2083**.
