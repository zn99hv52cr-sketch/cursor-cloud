# WR3000P: медленная отправка фото/видео в Telegram

## Почему

На **Cudy WR3000P** слабый CPU. Если Telegram в **podkop** (community list `telegram`), медиа идёт через **VLESS WebSocket** на FI — типично **~12–30 KB/s**, загрузки «висят».

Текст/мелочь могут терпеть; **фото и видио** — нет.

## Решение (два шага)

### 1. MTProxy Telemt на VPS (основное)

Ссылки лежат на VPS: `/root/creds/telemt-wr3000p-links.txt`  
Сервер: **`185.141.217.43:8443`**, Fake-TLS (SNI cloudflare.com).

**Telegram** → Настройки → **Данные и память** → **Прокси** → **Добавить прокси** → вставить ссылку `https://t.me/proxy?server=...` из файла (свой пользователь: admin / iTruba и т.д.).

Прокси **включить** (можно постоянно на WR3000P Wi‑Fi). Медиа пойдёт **мимо** podkop VLESS, напрямую на Telemt — скорость обычно **в разы выше**.

Проверка: в Telegram у прокси статус **Connected**, отправить видео 5–10 MB.

### 2. На роутере: убрать `telegram` из podkop

Чтобы клиент без прокси не дублировал путь через VLESS:

```bash
tailscale ssh root@100.104.207.62 'sh -s' < ops/scripts/wr3000p-telegram-no-vless.sh
```

Или LuCI → Podkop → community lists → снять **telegram** → Save → Restart.

**Не трогаем:** `russia_inside`, user_domains (rutracker, cursor, …). «Запрещёнка» и Cursor остаются в туннеле.

## LAN DNS (если rutracker/Cursor «отвалились»)

См. `ops/wr3000p-cursor-dns-fix.md`: DHCP `6,192.168.1.1`, redirect 53 в `firewall.user`.

## Tailscale SSH

Cloud Agent: `100.104.207.62` — один раз подтвердить `https://login.tailscale.com/a/...` в аккаунте sharpmaind.
