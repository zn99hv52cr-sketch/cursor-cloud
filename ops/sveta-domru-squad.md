# Sveta, Дом.ru, центр Петербурга

Дом.ru (ER-Telecom) DPI:

- TLS до своего SNI пропускает, **WebSocket через пару минут режет** (Upgrade + длинная сессия).
- Чужой Reality (`microsoft.com` на финский IP, порт 2053) **не доходит**.
- IP Cloudflare обычно не разбирают так же — трафик выглядит как обычный HTTPS на CF.

## Сейчас

Публичный 443 снова у Caddy. Для Светы отдельный Cloudflare quick tunnel (`cf-front` → `127.0.0.1:8080` → `/xh` и `/vpn`). Чужие хосты **не** переписываются.

1. **Дом.ru CF** — xHTTP packet-up через `*.trycloudflare.com`. Автоподключение.
2. **Megafon- Финляндия** — мобильная связь, прямой WS.
3. **Дом.ru CF WS** — WS через тот же CF.
4. Прямые packet-up / WS — запас, DPI их не любит.
5. Reality 2053 — в конце.

Туннель: `cf-front-tunnel.service`. URL для Светы обновляет `sveta-cf-front.timer`.

На iPhone потянуть подписку. Первая строка должна стать **Дом.ru CF**.
