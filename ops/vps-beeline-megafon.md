# Beeline vs Megafon on FI VPS (Юля + Эмиль)

2026-10-16. Юля Самойлова (Билайн) — при выборе Мегафона в подписке всё плохо грузилось. Эмиль — на Билайне тоже «плоховато». Проверка VPS / Remnawave / панелей.

## Почему так

На мобильном Билайне нормально живёт **xHTTP packet-up по HTTP/1.1**. WebSocket и gRPC (h2) Билайн режет или душит. Мегафон-профили в подписке — это как раз WS `/vpn`.

Что было в панели до правки:

- Хосты **Билайн packet-up / packet-up FF / stream-one / stream-up / WS** (сквад `Emil-Beeline`, режим `ALLOW_ONLY`) стояли **`isDisabled=true`**.
- `Emil_1`…`Emil_5` (только `Emil-Beeline`) видели **один** профиль: `Билайн` WS firefox.
- `Emil_6` сидит в **`Emil-Beeline` + `Default-Squad`** (Happ Portable). Default не снимали. Из‑за Default первым шёл `🇫🇮 Megafon- Финляндия` WS.
- `Julia_Samoilova_4/5/6` — сквад `South-RU-Beeline`. Первым тоже был Мегафон WS, dedicated packet-up им не отдавался.
- Старые `Julia_Samoilova`, `_2`, `_3` — MTS-сквады, не трогали.

Inbound `vless-xhttp` на ноде по-прежнему `mode=auto` (принимает packet-up / stream-up / stream-one).

## Что сделано (хосты Remnawave, не пользователи)

Бэкап: `/root/backups/hosts-20261016T203804Z/hosts.json`.

1. Включены шесть dedicated-хостов Билайн, в `ALLOW_ONLY` добавлен сквад `South-RU-Beeline` (Юля) рядом с `Emil-Beeline`. Порядок: packet-up → packet-up FF → stream-one → stream-up → WS → Билайн (firefox).
2. `viewPosition` packet-up = **0**, Мегафон остаётся **1**. Default-пользователи dedicated-хосты не видят, у них по-прежнему первым Мегафон (проверка: `Cudy_WR3000P`, `Podruga_Juli`).
3. `🇫🇮 Megafon- Финляндия` исключён из `South-RU-Beeline`, чтобы Юля не выбирала его по привычке. У `Emil_6` Мегафон **остался** во втором слоте — Default не трогали.

После обновления подписки (Happ / v2raytun):

| Кто | Сквады | Первый профиль | Мегафон в подписке |
|-----|--------|----------------|--------------------|
| `Emil_1`…`Emil_5` | только Emil-Beeline | Билайн packet-up (xHTTP `/xh/` http/1.1) | нет |
| `Emil_6` | Emil-Beeline **и Default** | Билайн packet-up | да, 2-м; дальше Yota/MTS/Tele2/RT |
| `Julia_Samoilova_4/5/6` | South-RU-Beeline | Билайн packet-up | нет |

На телефонах: обновить подписку и выбрать **Билайн packet-up**. Если не цепляется — packet-up FF, потом stream-one. Мегафон на Билайне не брать.

## VPS / панели (live 2026-10-16 ~20:40 UTC)

Все docker Up, failed systemd нет. Uptime ~1.5 суток. Egress src `193.124.224.248` (YouTube RU). Диск 17G/30G **58%**. RAM ок, swap почти пустой. Load ~2.1 на 2 CPU (remnawave + remnanode + caddy ~20% каждый) — не авария, но запас маленький.

| Сервис | Образ / версия | HTTP | Заметка |
|--------|----------------|------|---------|
| Remnawave | `backend:3` = **3.4.4** (latest 3.4.5 от 6 Oct) | vpn2 `401` — Caddy gate | healthy, 83 ACTIVE / 19 online |
| remnanode | `node:3.4.1` + Xray **26.7.28** | connected | не рестартовали |
| Caddy | 2.9.1 | 80/443 | vpn2 / awg / kuma / mtpanel |
| cf-front | caddy 2.11.6 | up | |
| Amnezia panel | `1.5.0` | awg `302` /login | healthy |
| amnezia-awg2 | 3.1 | UDP 51820 | |
| Uptime Kuma | `:1` (~год) | `302` /dashboard | **FI Remnawave = DOWN из‑за 401 gate** — ложная тревога; AWG panel / Sub API / Disk UP. Мониторы Dacha Air и AWG UDP выключены |
| vpn-bot | local image | up | Telegram getUpdates 200 |
| Telemt | systemd | `/mtpanel*` 401 снаружи, 200 на :8088 | Fake-TLS :8443 |
| postgres 17.6 / valkey 9 | healthy | | |

Политика `/root/creds/upgrade-watch.md`: **NEVER auto-upgrade**. Последняя проверка **2026-09-18** — вотчер фактически молчит. Apt: docker-ce 29.8→29.9 и мелкие noble-updates (tzdata, apparmor). **Не обновлял.**

## Особое внимание (не трогал без ОК)

- **Не авто-апгрейдить Remnawave 3.4.4→3.4.5** и node 3.4.1: тихий 3.4.5 чинит torrent-blocker id filter и xray-json transport names. Только в окно и с бэкапом.
- Kuma «FI Remnawave» надо либо научить 401, либо бить в API с токеном — иначе вечно DOWN после panel gate.
- Диск 58% / 12G free — не горит, но бэкапы в `/root/backups` лучше не копить бесконечно.
- Load ~2 на 2 ядрах: лишний restart ноды в час пик не делать (Света Reality и остальные на этом же Xray).
- `Emil_6` Default **не снимать** — Happ Portable собран на этой подписке.
- Юля 1–3 на MTS — не менял.
