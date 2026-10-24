# Angry Birds 2 на iPhone (Wi‑Fi TR3000)

## Симптом

- На **Wi‑Fi TR3000** без VPN на телефоне игра **не догружает** (застревает на загрузке).
- Если включить **Happ / свой VLESS на iPhone**, на стартовом экране: **«нет доступа к сети»**.

## Почему так

1. **Rovio** для РФ/РБ отключила магазины и ограничила сервисы; с **российского egress** (прямой выход с роутера) часть API/CDN **не открывается** или режется провайдером.
2. **Полный VPN на телефоне** поверх домашнего Wi‑Fi ломает картину: весь трафик идёт через FI, игра + рекламные SDK (Unity, AppLovin, Google) + иногда локальные проверки сети **конфликтуют** → сообщение «нет доступа к сети».
3. На iPhone **Private Relay / DoH / DNS не роутера** → домены Rovio **не попадают** в podkop FakeIP, трафик идёт мимо `sbtun`.

**Решение:** split-tunnel **на TR3000** (podkop): **только домены** игры/SDK в туннель (не весь iPhone, не `googleapis.com` целиком). На Wi‑Fi **VPN на телефоне выключить**.

## Домены в туннель

Скрипт `ops/scripts/tr3000-add-angrybirds-domains.sh` добавляет в `uci podkop.main.user_domains`:

| Группа | Домены |
|--------|--------|
| Rovio | `rovio.com`, `cloud.rovio.com`, `cdn.rovio.com`, `rovio-cdn.net`, `rovio-static.com` |
| SDK / реклама (старт игры) | `unity3d.com`, `unity.com`, `helpshift.com`, `applovin.com`, `applvn.com`, `vungle.com`, `mintegral.net`, `rayjump.com` |
| Google (часто нужен SDK) | `googleapis.com`, `gstatic.com`, `fundingchoicesmessages.google.com` |

Остальной LAN-трафик остаётся **напрямую**, как сейчас.

## Применить на TR3000

С ПК в Tailscale (один раз подтвердить SSH в аккаунте sharpmaind):

```bash
tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-angrybirds-domains.sh
```

Или LuCI → **Podkop** → user domains (те же имена) → Save → Restart podkop / sing-box.

После правки:

```bash
uci commit podkop
/etc/init.d/podkop restart
# если в logread «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

## iPhone 16 (обязательно)

1. **Happ / VPN выключить**, пока вы на Wi‑Fi TR3000.
2. Настройки → Wi‑Fi → (i) у сети TR3000:
   - **Configure DNS → Automatic** (DNS = роутер, обычно `192.168.x.1`).
   - **Limit IP Address Tracking** — выкл. для этой сети.
   - **iCloud Private Relay** — выкл. для этой сети (или глобально на время проверки).
3. Полностью **закрыть** Angry Birds 2 (смахнуть из переключателя) и запустить снова.

## Проверка

На роутере:

```bash
nslookup cloud.rovio.com 127.0.0.1
nslookup cdn.rovio.com 127.0.0.1
```

Ожидается FakeIP **`198.18.x.x`** на TR3000 (не публичный IP AWS/CloudFront).

С iPhone (если есть Shortcuts/Termius): `nslookup cloud.rovio.com` через DNS роутера — тот же FakeIP.

В Remnawave у пользователя роутера (**Cuddy_TR3000**) при запуске игры должен кратко обновиться `onlineAt`.

## Если всё ещё не грузит

1. **Не использовать** `fully_routed_ips` для iPhone — ломает остальной трафик телефона.
2. **Не добавлять** `googleapis.com` / `gstatic.com` целиком — слишком широко; только точечные хосты (Play/Firebase) в скрипте.
3. **`disable_quic=0`** (QUIC не режем глобально — иначе страдает «запрещёнка» и другие сайты).
2. В Happ на телефоне **удалить не использовать** для домашнего Wi‑Fi; для мобильного интернета Билайн — отдельно **Emil_1 / Билайн packet-up**, не полный «глобальный» режим вместе с Wi‑Fi.
3. Rovio официально **не обновляет** игру в РФ — старая сборка иногда не стартует даже с туннелем; тогда только другой Apple ID / регион или уже установленный кэш.

## Статус применения

| Роутер | Tailscale | FakeIP | Скрипт |
|--------|-----------|--------|--------|
| **TR3000** | `100.81.160.52` | `198.18.x.x` | применено 2026-10-24 (podkop + sing-box; `cloud.rovio.com` → `198.18.0.4`) |
| WR3000P | `100.104.207.62` | `198.20.x.x` | тот же скрипт при необходимости |
