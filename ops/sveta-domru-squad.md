# Sveta, Дом.ru, центр Петербурга

Дом.ru DPI режет долгий WS на прямой финский IP и не пускает Reality (2053 / чужой SNI). Cloudflare edge обычно не разбирают так же.

## Сейчас

1. **Дом.ru CF WS** — WebSocket через `*.trycloudflare.com` (не прямой `.43`). Автоподключение.
2. **Megafon- Финляндия** — мобильная связь.
3. **Дом.ru CF stream** — xHTTP stream-one через CF.
4. **Дом.ru CF** — xHTTP packet-up через CF.
5. Прямые packet-up / WS / Reality — запас.

Туннель: `cf-front-tunnel.service`. URL Светы: `sveta-cf-front.timer` (чужие хосты не трогает).

Happ routing: Telegram в прокси + DoH `1.1.1.1` + IPv4. Убран catch-all `regexp:.*\.ru$` из DirectSites — мешал стабильному проксированию.

На iPhone потянуть подписку. Первая строка — **Дом.ru CF WS**.
