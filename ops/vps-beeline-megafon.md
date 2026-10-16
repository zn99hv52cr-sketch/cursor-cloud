# Beeline vs Megafon on FI VPS (Юля + Эмиль)

2026-10-16. Юля Самойлова (Билайн) — при выборе Мегафона в подписке всё плохо грузилось. Эмиль — на Билайне тоже «плоховато». Проверка VPS / Remnawave / панелей.

## Почему так

На мобильном Билайне нормально живёт **xHTTP packet-up по HTTP/1.1**. WebSocket и gRPC (h2) Билайн режет или душит. Мегафон-профили в подписке — это как раз WS `/vpn`.

Что было в панели до правки:

- Хосты **Билайн packet-up / packet-up FF / stream-one / stream-up / WS** (сквад `Emil-Beeline`, режим `ALLOW_ONLY`) стояли **`isDisabled=true`**.
- `Emil_1`…`Emil_5` (только `Emil-Beeline`) видели **один** профиль: `Билайн` WS firefox.
- `Emil_6` был в **`Emil-Beeline` + `Default-Squad`** (Happ Portable). Оставлен **только Default**.
- `Julia_Samoilova_4/5/6` — сквад **`South-RU-Beeline` = Ставрополье**. Его оставляем. Первым шёл Мегафон WS, ставропольские Билайн-хосты были ниже (pos 13–15).
- Старые `Julia_Samoilova`, `_2`, `_3` — MTS-сквады, не трогали.

Inbound `vless-xhttp` на ноде по-прежнему `mode=auto` (принимает packet-up / stream-up / stream-one).

## Что сделано (хосты Remnawave, не пользователи)

Бэкап: `/root/backups/hosts-20261016T203804Z/hosts.json`.

1. Включены шесть dedicated-хостов Билайн **только для `Emil-Beeline`**. Первая попытка повесить их ещё и на `South-RU-Beeline` отменена: South — это Ставрополье, его каталог не смешиваем с эмилевским.
2. `viewPosition` Emil packet-up = **0**, Мегафон остаётся **1**. Default / `happ` dedicated-хосты Эмиля не видят, у них первым Мегафон (проверка: `Cudy_WR3000P`, `Emil_6`).
2b. Для Happ Portable заведён сквад **`happ`** (`7c685797-a739-4383-995e-484d5f55e361`), те же инбаунды что у Default. `Emil_6` только в `happ` (не Default, не Emil-Beeline). Каталог как у Default: Мегафон первым, 15 профилей. Хосты, скрытые от Default, скрыты и от `happ`.
3. Юля **осталась** в `South-RU-Beeline`. Мегафон в этот сквад вернули. Первыми стоят ставропольские Билайн: xHTTP (packet-up, ALPN `http/1.1`) → WS (`http/1.1`) → gRPC. Мегафон в её подписке 4-м, не удалён.

После обновления подписки (Happ / v2raytun):

| Кто | Сквады | Первый профиль | Мегафон в подписке |
|-----|--------|----------------|--------------------|
| `Emil_1`…`Emil_5` | только Emil-Beeline | Билайн packet-up (xHTTP `/xh/` http/1.1) | нет |
| `Emil_6` | **happ** (Happ Portable) | 🇫🇮 Megafon- Финляндия | да, 1-м; 15 профилей |
| `Julia_Samoilova_4/5/6` | South-RU-Beeline (Ставрополье) | 🏔 Ставрополь Билайн-xHTTP | да, 4-м |

На телефонах `Emil_1`…`Emil_5`: обновить подписку и выбрать **Билайн packet-up**. `Emil_6` (Happ Portable): обновить подписку — сквад `happ`, Мегафон первым. Юле — **🏔 Ставрополь Билайн-xHTTP**, запасной WS. Мегафон на Билайне не брать.

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

Политика `/root/creds/upgrade-watch.md`: **NEVER auto-upgrade**. Apt: docker-ce 29.8→29.9 и мелкие noble-updates. **Не обновлял.**

## Вотчер обновлений (почему «молчит с 18 сентября»)

Это **не сервис**. 18 сентября агент оставил два файла-шпаргалки:

- `/root/creds/upgrade-watch.md` — две строки: смотреть раз в 30 минут, **никогда не катить самим**, в тихое окно спросить.
- `/root/creds/upgrade-watch-lastcheck.txt` — штамп `CHECK=2026-09-18 23:30:33 UTC` (разовый прогон в тот же вечер).

Cron / systemd timer / скрипта, который это пишет, **нет**. В crontab только диск→Kuma, продление сертификата Caddy и монитор дачи AWG. Поэтому штамп не двигается: проверять некому. Политика «не автоапгрейд» от этого не ломается — просто отчёта каждые 30 минут нет. Ставить вотчер не стал.

## Особое внимание (не трогал без ОК)

- **Не авто-апгрейдить Remnawave 3.4.4→3.4.5** и node 3.4.1: тихий 3.4.5 чинит torrent-blocker id filter и xray-json transport names. Только в окно и с бэкапом.
- Kuma «FI Remnawave» надо либо научить 401, либо бить в API с токеном — иначе вечно DOWN после panel gate.
- Диск 58% / 12G free — не горит, но бэкапы в `/root/backups` лучше не копить бесконечно.
- Load ~2 на 2 ядрах: лишний restart ноды в час пик не делать (Света Reality и остальные на этом же Xray).
- `Emil_6` держать **только в скваде `happ`**. Не возвращать в Default и не в Emil-Beeline.
- `South-RU-Beeline` **не разбирать** и не кормить эмилевскими dedicated-хостами — это Ставрополье.
- Юля 1–3 на MTS — не менял.
