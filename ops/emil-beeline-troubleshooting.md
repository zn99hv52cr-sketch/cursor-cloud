# Emil Izmailov — Билайн: «VPN перестал работать»

## Быстрая диагностика (1 минута)

| Вопрос | Если «да» → действие |
|--------|----------------------|
| Эмиль на **Билайн** и открыл подписку **`Emil_6` / Happ Portable**? | Перейти на **`Emil_1`…`Emil_5`** или в Happ выбрать профиль **Билайн packet-up**, не Мегafon |
| Давно не **обновлял подписку**? | Happ → обновить URL подписки |
| В списке только **«Билайн» WS** или **Megafon**? | На сервере выключены xHTTP-хосты — см. скрипт ниже |
| Ссылка **`vpn.sharpmaind.ru`** без **2**? | Заменить на **`vpn2.sharpmaind.ru`** |
| В Happ включён **автовыбор** / другой VPN? | Выключить, выбрать профиль вручную |

## Что сделать на сервере (VPS)

```bash
# на VPS, JWT: /opt/remnawave/remnawave-vpn-bot.jwt или /root/creds/
bash ops/scripts/remnawave-fix-emil-beeline.sh --apply
```

Скрипт (dry-run по умолчанию):

- Проверяет `Emil_1`…`Emil_5` → только сквад **Emil-Beeline**, статус ACTIVE.
- Проверяет `Emil_6` → только **`happ`** (не Default + не Emil-Beeline).
- Список хостов сквада Emil-Beeline: **packet-up включён и первый**.
- Подсказка по inbound xHTTP `mode=auto`.

## Что сделать Эмилю (инструкция текстом)

**Основной телефон (SIM Билайн):**

1. Подписка **`Emil_1`** (или `_2`…`_5` — какую выдавали), URL с **vpn2**.
2. Обновить подписку.
3. Профиль: **«Билайн packet-up»** (иконка xHTTP / `/xh/`).
4. Не работает → **«Билайн packet-up FF»** → **stream-one** → **stream-up**.

**Happ Portable (`Emil_6`):**

- Для поездок с **Мегafon / Yota / MTS** — ок.
- На **Билайн** portable **не подходит** как единственная подписка (Мегafon первым).

## Если Билайн снова ужесточил DPI (идеи на будущее)

1. **Reality** на `:2053` под «безобидным» SNI (как у Sveta Skynet) — отдельный хост только в `Emil-Beeline`, вторым после packet-up.
2. **packet-up FF** поставить **первым** на 2 недели A/B.
3. Алерт в access.log: если `email` Эмиля часто на **gRPC** или **Megafon WS** — значит клиент не обновил подписку.
4. Не смешивать **`South-RU-Beeline`** (Ставрополь) с **`Emil-Beeline`** — разные каталоги хостов.

## Проверка с VPS после фикса

```bash
curl -fsS --resolve vpn2.sharpmaind.ru:443:127.0.0.1 \
  -H "Authorization: Bearer $TOKEN" \
  "https://vpn2.sharpmaind.ru/api/users/by-username/Emil_1" | jq '.response.status,.response.activeInternalSquads'
docker exec remnanode tail -100 /var/log/remnanode/access.log | grep 'email: <id>'
```
