# Sveta, Дом.ru, центр Петербурга

Пользователь `Sveta` (id 5, short uuid `RnqwjtrNjArut7LD`) переехала в центр Петербурга: домашний провайдер теперь **Дом.ru** (ER-Telecom), не Скайнет. Клиент: Happ на iPhone.

Сквад тот же UUID, имя сменено.

| | |
|---|---|
| Сквад | `Sveta-DomRu` (`b52de567-f64e-4951-94f2-08689b9a3983`) |
| Подписка | `https://vpn2.sharpmaind.ru/api/sub/RnqwjtrNjArut7LD` |

Хосты только этого сквада (`ALLOW_ONLY`), адрес панели не трогал. Happ берёт **первую** строку для автоподключения.

## Порядок в подписке (2026-11-02)

1. **Дом.ru Reality** — `185.141.217.43:2053`, SNI `www.microsoft.com`. Для домашнего Wi‑Fi Дом.ru это основной профиль: DPI режет обычный TLS на 443 с именем панели.
2. **Дом.ru packet-up** — xHTTP, ALPN `http/1.1`, safari
3. **Дом.ru packet-up iOS** — то же, отпечаток ios
4. **Дом.ru Safari** — xHTTP stream-one
5. **Дом.ru iOS** — xHTTP stream-up
6. **Дом.ru WS** — WebSocket, safari
7. **Дом.ru WS FF** — WebSocket, firefox (как у Ростелекома/кабеля)
8. **Megafon- Финляндия** — запас для мобильного Мегафона

На iPhone в Happ обновить подписку. Дома оставить первую строку **Дом.ru Reality**. Если 2053 режется — вторая, `packet-up`. На сотовом Мегафоне можно последнюю строку.

Чужие сквады не задеты: в Default-Squad профилей Дом.ru нет.
