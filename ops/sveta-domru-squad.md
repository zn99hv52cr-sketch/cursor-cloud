# Sveta, Дом.ru — копаем Megafon (только сквад Sveta-DomRu)

На Wi‑Fi Дом.ru Megafon WS цепляется, потом DPI рвёт долгую сессию. Правки **только** в ALLOW_ONLY хостах сквада `b52de567-…` (Sveta-DomRu). Общий Megafon / Caddy / чужие юзеры не трогаем.

## Порядок в подписке (после обновления)

1. **Megafon- packet-up** — xHTTP `/xh/`, mode packet-up, padding, fp safari  
2. **Megafon- stream-up** — xHTTP stream-up  
3. **Megafon- packet-up iOS** — то же + fp ios  
4. **Megafon- stream** — stream-one  
5. **Megafon- Финляндия** — WS `/vpn` safari (мягкий keepalive 300/120, без TFO)  
6. **Megafon- FF** / **Megafon- iOS** — WS запас  
7. Дом.ru fallbacks

Все Megafon-* с тегами `MEGAFON,SVETA` → `internalSquads: ALLOW_ONLY [Sveta-DomRu]`.

## Что сделать на iPhone

Потянуть подписку в Happ. Автоподключение должно взять **packet-up**. Если отвалится — руками **stream-up** или **packet-up iOS**. WS (#5) оставить на проверку «цепается / рвёт».

## Не менять глобально

- Caddy `/vpn` (уже flush; не трогать дальше без нужды)  
- Shared `🇫🇮 Megafon- Финляндия` (`a03f6bc3…`, fp chrome) для Default-Squad  
- Reality / CF — скрыты у неё, не возвращать без запроса  
