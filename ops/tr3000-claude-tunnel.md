# Claude (claude.ai) через туннель — TR3000

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

## Применение на TR3000

С ПК в Tailscale:

```bash
tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-claude-domains.sh
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
nslookup claude.ai 127.0.0.1
nslookup assets-proxy.anthropic.com 127.0.0.1
```

Ответ **`198.18.x.x`** (FakeIP TR3000) — DNS отдаёт туннель.

С LAN: открыть https://claude.ai — в Remnawave у **Cuddy_TR3000** должен обновиться `onlineAt`.

## Доступ агента

Cloud Agent: `tailscale ssh root@100.81.160.52` — один раз подтвердить ссылку `https://login.tailscale.com/a/...`. Без Tailscale правку можно выполнить с вашего ПК командой выше или LuCI → Podkop → User domains.
