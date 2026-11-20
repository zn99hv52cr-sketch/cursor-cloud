# TR3000 — Cursor на Wi‑Fi без iOS VPN

**Роутер:** Cudy TR3000 (`100.81.160.52`). WR не трогаем.

## Симптом

Cursor на Wi‑Fi TR «тупит» (чат, agents, логин), пока на iPhone не включён VPN. С VPN на iOS — нормально.

## Причина

1. iOS часто **не использует DNS роутера** (iCloud Private Relay, «Ограничить трекинг IP», DoH) → реальные IP Cloudflare/Vercel, **мимо** fakeip/podkop, дальше МГТС.
2. Даже при DNS роутера нужны **подсети**: `api2.cursor.sh` сейчас `104.18.18.125` / `104.18.19.125`, сайт `cursor.com` — Vercel `76.76.21.x` / `66.33.60.x`. В nft были только два `/32` на `104.18.30/31`.
3. Новый логин: `accounts.spacex.ai`, `accounts.x.ai`, `workos.com`.

Домены `cursor.com` / `cursor.sh` в `user_domains` уже были (и в russia_inside).

## Фикс на TR (2026-11-20)

**`user_domains`:** `accounts.spacex.ai`, `accounts.x.ai`, `workos.com`, `download.todesktop.com`, `downloads.cursor.com`, `agent-stores.s3.us-east-1.amazonaws.com`.

**`user_subnets`:** только точечные CF `/32` + Vercel `76.76.0.0/16` + `66.33.60.0/23`.  
**Нельзя** `104.16.0.0/12` и `172.64.0.0/13` — через туннель уезжает пол-Cloudflare, **YouTube падает**.

```sh
sh ops/scripts/tr3000-cursor-wifi.sh
```

## На iPhone (этот Wi‑Fi)

Настройки → Wi‑Fi → сеть TR → выключить **iCloud Private Relay** и **Ограничить трекинг IP**. Иначе часть трафика всё равно уйдёт в Relay, не в podkop.

После правки: выключить iOS VPN, перезайти в Cursor (приложение или Safari).