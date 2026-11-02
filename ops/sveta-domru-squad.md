# Sveta, Дом.ru, центр Петербурга

Пользователь `Sveta` (id 5, short uuid `RnqwjtrNjArut7LD`) переехала в центр Петербурга: домашний провайдер теперь **Дом.ru** (ER-Telecom), не Скайнет. Клиент: Happ на iPhone.

Сквад тот же UUID, имя сменено.

| | |
|---|---|
| Сквад | `Sveta-DomRu` (`b52de567-f64e-4951-94f2-08689b9a3983`) |
| Подписка | `https://vpn2.sharpmaind.ru/api/sub/RnqwjtrNjArut7LD` |

Хосты только этого сквада (`ALLOW_ONLY`), адрес панели не трогал. Happ берёт **первую** строку для автоподключения.

## Порядок в подписке (2026-11-02, после Wi‑Fi)

Дом.ru с домашнего Wi‑Fi (`Happ/4.7.2` iOS) порт **2053 не пускает**: после Reality первым в списке до ноды не было ни одного `vless-reality`. До этого с той же сети стабильно жил `vless-main` на 443.

1. **Дом.ru WS** — WebSocket 443, safari. Автоподключение Happ.
2. **Дом.ru packet-up** — xHTTP, ALPN `http/1.1`, safari
3. **Дом.ru packet-up iOS**
4. **Дом.ru WS FF** — WebSocket, firefox
5. **Дом.ru Safari** / **Дом.ru iOS** — xHTTP stream
6. **Megafon- Финляндия** — мобильный Мегафон
7. **Дом.ru Reality** — `:2053`, SNI Microsoft. Оставлен в конце: с Дом.ru Wi‑Fi не доходит.

2026-11-02 10:21 MSK: с домашнего Wi‑Fi Дом.ru первая строка **Дом.ru WS** заработала.

На iPhone в Happ обновить подписку. Дома оставить **Дом.ru WS**. Если слабо — вторая, `packet-up`.

Чужие сквады не задеты: в Default-Squad профилей Дом.ru нет.
