# WR3000P: Cursor + «запрещёнка» (2026-10-21)

## Симптом

С LAN Cursor тормозит / не работает, rutracker и прочие сайты из podkop не открываются, хотя с самого роутера всё OK.

## Причины

1. **Клиенты не используют DNS роутера** (DoH в браузере, 8.8.8.8 / 1.1.1.1) → нет FakeIP `198.20.x.x`, трафик мимо `sbtun`.
2. **Два процесса sing-box** после аварийных перезапусков → нестабильный туннель.
3. Telegram через VLESS на слабом CPU WR3000P даёт ~12–30 KB/s; для TG лучше **Telemt MTProxy** (`185.141.217.43:8443`), ссылки на VPS: `/root/creds/telemt-wr3000p-links.txt`.

## Что сделано на роутере

- `podkop` / `sing-box` / `sbtun` восстановлены; transport **WS `/vpn`**, без xhttp.
- **DHCP**: `list dhcp_option '6,192.168.1.1'` — только DNS роутера.
- **`/etc/firewall.user`**: redirect UDP/TCP 53 с LAN на роутер (podkop FakeIP).
- Домены Cursor в списке: `cursor.com`, `cursor.sh`, `cursorapi.com`, `cursorvm.com`, `gcpp.cursor.sh`, `marketplace.cursorapi.com`, …
- `rutracker.org`, `rutor.is`, `nnmclub.to` — в туннеле.

## Проверка с ПК (Andrei-PC `192.168.1.236`)

```text
nslookup cursor.com 192.168.1.1   → 198.20.x.x
nslookup rutracker.org 192.168.1.1 → 198.20.x.x
```

В Cursor/Windows: отключить **Secure DNS / DoH**; DNS адаптера — **192.168.1.1** (или «получить автоматически» от роутера).

После смены DNS: `ipconfig /flushdns` (Windows).

## Telemt для Telegram (видео)

Не гонять медиа TG через podkop VLESS. В Telegram → Настройки → Данные → Прокси → добавить ссылку из `/root/creds/telemt-wr3000p-links.txt` на VPS.
