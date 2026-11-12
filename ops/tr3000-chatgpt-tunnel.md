# ChatGPT через туннель (TR3000 + WR3000P)

## Домены

Добавить в `uci podkop.main.user_domains` (dynamic):

| Домен | Назначение |
|-------|------------|
| `chatgpt.com` | веб и приложения |
| `openai.com` | общий бренд / редиректы |
| `chat.openai.com` | legacy URL |
| `api.openai.com` | API и клиент |
| `auth.openai.com` | вход |
| `platform.openai.com` | platform |
| `oaistatic.com` | статика UI |
| `oaiusercontent.com` | вложения / файлы |
| `ab.chatgpt.com` | A/B |
| `ws.chatgpt.com` | WebSocket |

Не трогать остальной список (rutracker, cursor, rezka, battle.net, HP и т.д.).

## Применение

С ноутбука (Tailscale SSH):

```bash
# TR3000
tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-chatgpt-domains.sh
# WR3000P
tailscale ssh root@100.104.207.62 'sh -s' < ops/scripts/tr3000-add-chatgpt-domains.sh
```

Или на роутере вручную — скрипт: `ops/scripts/tr3000-add-chatgpt-domains.sh`.

После правки:

```bash
uci commit podkop
/etc/init.d/podkop restart
# если в logread «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

## Статус

| Роутер | Tailscale | FakeIP | Применено |
|--------|-----------|--------|-----------|
| **TR3000** | `100.81.160.52` | `198.18.x.x` | 2026-10-20 |
| **WR3000P** | `100.104.207.62` | `198.20.x.x` | 2026-10-20 |

На обоих: 10 доменов в `user_domains`, podkop + sing-box перезапущены. Пример DNS: TR3000 `chatgpt.com` → `198.18.1.128`; WR3000P → `198.20.1.43`.

## Проверка

На роутере:

```bash
nslookup chatgpt.com 127.0.0.1
```

Ответ **`198.18.x.x`** (FakeIP TR3000) — DNS отдаёт туннель. Публичный IP — правка не применилась или sing-box не перечитал конфиг.

С LAN: открыть https://chatgpt.com — в Remnawave у **Cuddy_TR3000** должен обновиться `onlineAt`.

## Доступ агента

Cloud Agent: `tailscale ssh root@100.81.160.52` — один раз подтвердить ссылку `https://login.tailscale.com/a/...` в аккаунте sharpmaind. Без этого правки на роутере делаются с вашего ПК или через LuCI → Podkop.


## WR3000P incident 2026-11-12 (YT/TG/IG down)

- Symptom: Wi‑Fi phone + TV — YouTube/Telegram/Instagram dead; direct WAN OK.
- Root causes (stacked):
  1. `sing-box` crash loop `initialize cache-file: timeout` → FakeIP answered, tunnel dead.
  2. `urltest_proxy_links` still mostly on `185.141.217.43`.
  3. Leftover `/etc/dnsmasq.d/vpn2-newip.conf` pinned `vpn2` to `185.141.217.43` (dual A with 161).
- Fix applied on device:
  - Backups under `/overlay/backups/wr3000p-podkop-*`, `wr3000p-harden-*`.
  - Wipe `/tmp/sing-box/cache.db*`, restart podkop/sing-box.
  - `proxy_config_type=url`, single stable link `vless://…@89.125.57.161:443` WS `/vpn` (Reality delay-tests fail on this OpenWrt via HAProxy; not used).
  - `disable_quic=1`; TV keep `tv-quic-block` for `192.168.1.164`.
  - Rewrite `/etc/dnsmasq.d/vpn2-newip.conf` + `/etc/hosts` → `89.125.57.161` for `vpn2`/`awg`.
- Verified: sequential HTTP 200/204 for YT/TG/IG/FB via FakeIP; `vpn2` resolves only to 161.
