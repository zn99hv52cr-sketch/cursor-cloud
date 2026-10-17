# База: локальный чат `whitelists` (17 окт 2026)

Принято как операционная память из локального агента. Источник: `chat-backup-2026-10-17.whitelists.zip` (чат `58d3297b-1e88-4642-af9d-7c921dcb4257`).

Полный zip + transcript: VPS `/root/backups/chat-whitelists-2026-10-17/` и store агента `/cursor/stores/self/knowledge/whitelists-2026-10-17/`. Репозиторий публичный — сырой transcript в git не клали.

## Итог дня (канон)

### 1. HP Support Assistant
- Домены HP / HPSA в podkop на **TR3000** (`100.81.160.52`); FakeIP → туннель.
- WR3000P по просьбе тогда не трогали.
- Окно «HP более не осуществляет деятельность» — не DNS, а **регион Windows**. GeoId сменён на Финляндию (77). Язык не меняли. После этого HPSA открывается.

### 2. HDRezka на Mi TV Box (сеть TR3000, `192.168.2.145`)
- CDN: `crimson.voidcrystal.org` → `212.124.96.9` (AS47328 DigitalOne), было 1–3 Мбит/с напрямую.
- На TR3000 в туннель: подсеть **`212.124.96.0/19`** и домен **`voidcrystal.org`** (на всю LAN TR3000).
- Бэкап скрипта: `/usr/bin/podkop-tun-up.bak-rezka-20261017`.

### 3. То же на WR3000P (`100.104.207.62`)
- `212.124.96.0/19` + `voidcrystal.org` в podkop.
- В `/usr/bin/podkop-tun-up`: `ip route replace 212.124.96.0/19 dev sbtun`.
- Проверено `reboot -f`: туннель (ws), FakeIP, маршрут CDN поднимаются сами.
- Временный crontab убран, осталась `podkop list_update`.

### 4. TR3000 после отключения питания
- Туннель / FakeIP (HDRezka, support.hp.com) / маршрут CDN поднимаются сами.
- 404 на `192.168.2.1` — это был Wi‑Fi **Ростелеком RV6699**, не TR3000.
- LuCI TR3000 даёт 403 (логин), когда ноут в `Volshebny Dom_5G`.

### 5. Tailscale TR3000 уходил offline
- В `podkop-tun-up` был маршрут **`194.221.0.0/16` → sbtun** (ретранслятор Tailscale, Варшава / `45.159.98.196`).
- Маршрут **убран**; ретранслятор идёт direct через провайдера. Overlay переживает reboot.
- На WR3000P такого маршрута не было.

## Связь с облачным чатом 16 окт
- FI VPS: inbound `.43`, egress `.248` (YouTube RU).
- Юля = South-RU-Beeline (Ставрополье); Emil_1–5 = Emil-Beeline packet-up; Emil_6 = сквад `happ`.
- Не класть `194.221.0.0/16` в sbtun снова. Не SNAT весь eth0. Не снимать Default/happ у Emil_6 без просьбы.
