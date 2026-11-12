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

See also `ops/wr3000p-vpn.md` (canonical for this router). **Do not clone TR3000 wholesale** — different ISP (Rostelecom) and FakeIP/TUN layout.

- Symptom: Wi‑Fi phone + TV — YouTube/Telegram/Instagram dead; often “green from router” then dead after reboot.
- Earlier stacked causes: `sing-box` cache crash; stale `185`/`161` DNS pins; Reality unusable via HAProxy on this OpenWrt.
- **Working stack (device, late 2026-11-12):** same family as historical `bak-dualfix` on **this** WR3000P — not stock tproxy alone:
  - sing-box inbound **TUN** `sbtun` + FakeIP `198.20.0.0/15` + static routes (Google/Meta/TG) via `sbtun`
  - Dual VLESS **WS** `/vpn`: `89.125.57.161` (`main-1`) + `185.141.217.43` (`main-2`)
  - **Prefer `main-2` (185)** as selector default — Rostelecom intermittently `dial tcp 161:443 i/o timeout` while bare TCP still looks fine
  - `tcp_fast_open=false`
  - Helpers: `/usr/bin/podkop-tun-up`, `S99podkop-tun` watch, `podkop-guard`, `podkop-path-watch` (flip to 185 if path dies)
  - TV `192.168.1.164`: DNS DNAT to `1.1.1.1` (bypass FakeIP) + QUIC/DoH blocks
- Note: `nft flush` of unused `PodkopTable` tproxy chains is expected in TUN mode **only if** `sbtun` + FakeIP routes are present. Disabling `podkop-tun-up` and leaving FakeIP without TUN/routes is what made reboot “undo” earlier fixes.
