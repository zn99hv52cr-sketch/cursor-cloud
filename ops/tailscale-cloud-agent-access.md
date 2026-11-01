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

## 2. ACL и теги на роутерах (IP/имя в SSH **не работают**)

В Tailscale SSH в **Destination** можно только **тег**, не `cudy-tr3000` и не `100.81.x.x`.

### Вариант A — агент сам (рекомендуется)

1. [API access token](https://login.tailscale.com/admin/settings/keys) → секрет **`TAILSCALE_API_KEY`** в Environment.
2. Новый агент запускает:
   ```bash
   bash ops/scripts/tailscale-apply-cursor-cloud-acl.sh
   ```
   Скрипт: тег **`tag:cudy`** на TR3000/WR3000P + SSH `accept` **`tag:cursor-cloud` → `tag:cudy`**, user `root`.

### Вариант B — вручную в UI

1. **Definitions → Tags:** `cudy` (owner admin), `cursor-cloud` (owner admin).
2. **Machines →** cudy-tr3000 и cudy-wr3000p → **Edit tags** → **`tag:cudy`**.
3. **Policies → Tailscale SSH → Add rule:** Source `tag:cursor-cloud`, Destination **`tag:cudy`**, user `root`, Check **Off**.

Auth key агента — с **Tags → `tag:cursor-cloud`**.

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
