# Cloud Agent → Cudy без ручного «Approve»

Два слоя, из‑за которых раньше просили ссылку:

1. **VM агента не в Tailscale** — лечится секретом `TAILSCALE_AUTHKEY` и скриптом `.cursor/start-tailscale.sh` при старте окружения.
2. **SSH check на роутер** — в ACL tailnet правило `accept` для `tag:cursor-cloud` → TR3000 / WR3000P (без `check`).

## 1. Ключ Tailscale (один раз)

[Admin → Keys](https://login.tailscale.com/admin/settings/keys) → **Generate auth key**:

| Поле | Значение |
|------|----------|
| Reusable | да |
| Ephemeral | **нет** |
| Pre-approved | да |
| Tags | `tag:cursor-cloud` |

Скопировать ключ в **Cursor → Cloud Agents → Environments → cursor-cloud → Secrets** как **`TAILSCALE_AUTHKEY`**.

## 2. ACL: тег и SSH без check

[Access controls](https://login.tailscale.com/admin/acls) → JSON. Добавить (или слить с вашим файлом):

```json
"tagOwners": {
  "tag:cursor-cloud": ["autogroup:admin"]
},
"ssh": [
  {
    "action": "accept",
    "src": ["tag:cursor-cloud"],
    "dst": ["100.81.160.52", "100.104.207.62"],
    "users": ["root"]
  }
]
```

Правило **`accept` для `tag:cursor-cloud` должно быть выше** любого общего `"action": "check"` для `autogroup:member`, иначе снова будет ссылка на TR3000.

Сохранить ACL. Новые агенты с ключом получат тег `cursor-cloud` автоматически.

## 3. Окружение Cursor

В репозитории:

- `.cursor/environment.json` — `install` (tailscale, sshpass) + `start` → `.cursor/start-tailscale.sh`
- после Save окружения каждый новый агент сам поднимает Tailscale.

Проверка с агента:

```bash
tailscale status | grep -E 'tr3000|wr3000'
tailscale ssh root@100.81.160.52 'echo ok-tr3000'
tailscale ssh root@100.104.207.62 'echo ok-wr3000p'
```

## Роутеры

На TR3000 и WR3000P уже `RunSSH: true`. Менять LuCI не нужно.
