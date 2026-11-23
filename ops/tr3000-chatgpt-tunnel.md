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

**Рабочий путь (облако, без браузера):** dropbear на **порту 2222**, ключ `wr3000p_ed25519` — Tailscale **не** перехватывает этот порт.

```bash
ssh -p 2222 -i ~/.ssh/wr3000p_ed25519 root@100.81.160.52
# или: ssh tr3000   # если в ~/.ssh/config Port 2222
```

**Не использовать для агента:** `root@100.81.160.52` без `-p 2222` и `tailscale ssh` — на **22** включён Tailscale SSH (`RunSSH: true`): требуется разовый клик `https://login.tailscale.com/a/...`, облако само не подтвердит.

Исторически (октябрь): `tailscale up --auth-key=... --hostname=cursor-agent --accept-routes=false --ssh` + `tailscale ssh root@100.81.160.52` после вашего подтверждения `/a/...`. Сейчас на TR снова `RunSSH: true` после ребута — оставлен обход через **2222**.
