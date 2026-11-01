# Claude (claude.ai) через туннель — TR3000 / WR3000P

## Домены

Добавить в `uci podkop.main.user_domains` (как ChatGPT — только дополнение списка):

| Домен | Назначение |
|-------|------------|
| `claude.ai` | веб, приложение |
| `anthropic.com` | бренд, редиректы |
| `api.anthropic.com` | API и чат с сервера |
| `assets-proxy.anthropic.com` | JS/CSS Next.js (без него — белый экран) |
| `s-cdn.anthropic.com` | старый CDN статики |
| `claudeusercontent.com` | артефакты, вложения, iframe |
| `platform.claude.com` | console / docs |
| `console.anthropic.com` | вход в консоль (если открываете) |

Не трогать остальной `user_domains` (telegram, rezka, cursor, chatgpt и т.д.).

## Применение

С ПК в Tailscale (один и тот же скрипт):

```bash
# TR3000 (дом)
tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-claude-domains.sh
# WR3000P (вторая квартира)
tailscale ssh root@100.104.207.62 'sh -s' < ops/scripts/tr3000-add-claude-domains.sh
```

Или скопировать скрипт на роутер: `ops/scripts/tr3000-add-claude-domains.sh`.

После правки вручную:

```bash
uci commit podkop
/etc/init.d/podkop restart
# если в logread «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

## Проверка

На роутере:

```bash
nslookup claude.ai 127.0.0.42
nslookup assets-proxy.anthropic.com 127.0.0.42
# или с LAN-адреса роутера:
nslookup claude.ai 192.168.2.1
```

Ответ **`198.18.x.x`** (FakeIP podkop) — DNS отдаёт туннель.

С LAN: открыть https://claude.ai — в Remnawave должен обновиться `onlineAt` у **Cuddy_TR3000** или **WR3000P**.

## Статус

| Роутер | Tailscale | Применено |
|--------|-----------|-----------|
| **TR3000** | `100.81.160.52` | 2026-11-01 |
| **WR3000P** | `100.104.207.62` | 2026-11-01 |

## Доступ агента

Cloud Agent: `tailscale ssh root@100.81.160.52` — один раз подтвердить ссылку `https://login.tailscale.com/a/...`. Без Tailscale правку можно выполнить с вашего ПК командой выше или LuCI → Podkop → User domains.
