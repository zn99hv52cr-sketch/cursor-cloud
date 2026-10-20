# ChatGPT через туннель на Cudy TR3000

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

С ноутбука (Tailscale SSH уже одобрен на вашем аккаунте):

```bash
tailscale ssh root@100.81.160.52 'sh -s' < ops/scripts/tr3000-add-chatgpt-domains.sh
```

Или на роутере вручную — скрипт: `ops/scripts/tr3000-add-chatgpt-domains.sh`.

После правки:

```bash
uci commit podkop
/etc/init.d/podkop restart
# если в logread «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

## Проверка

На роутере:

```bash
nslookup chatgpt.com 127.0.0.1
```

Ответ **`198.18.x.x`** (FakeIP TR3000) — DNS отдаёт туннель. Публичный IP — правка не применилась или sing-box не перечитал конфиг.

С LAN: открыть https://chatgpt.com — в Remnawave у **Cuddy_TR3000** должен обновиться `onlineAt`.

## Доступ агента

Cloud Agent: `tailscale ssh root@100.81.160.52` — один раз подтвердить ссылку `https://login.tailscale.com/a/...` в аккаунте sharpmaind. Без этого правки на роутере делаются с вашего ПК или через LuCI → Podkop.
