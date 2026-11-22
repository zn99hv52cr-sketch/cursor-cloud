# Восстановление TR3000 из `tr3000-backup-*.tar.gz`

Бэкап **не хранится в git** (там KotiKey subscription links). Архив создаётся **на роутере** (`tr3000-backup-full.sh`).

## 1. Создать архив (Cudy, Termius)

```sh
wget -qO- "https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/tr3000-backup-full.sh" | sh
```

Внутри обязательно: `etc-config/`, `koti-k-kotikey/` (если USB подключён), `uci-export-podkop.txt`, `sing-box/`.

## 2. Скачать на ПК

```sh
scp root@192.168.2.1:/tmp/tr3000-backup-*.tar.gz .
```

## 3. Отправить в Telegram (FI VPS, бот)

```sh
curl -fsSL "https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/tr3000-send-backup-telegram.sh" -o /tmp/send-bak.sh
chmod +x /tmp/send-bak.sh
scp root@YOUR_PC_IP:/path/tr3000-backup-*.tar.gz /tmp/   # или положи файл на VPS вручную
CHAT_ID=186409737 /tmp/send-bak.sh /tmp/tr3000-backup-*.tar.gz
```

## 4. Восстановить на роутере

```sh
scp tr3000-backup-XXXX.tar.gz root@192.168.2.1:/tmp/
wget -qO- "https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/tr3000-restore-from-backup.sh" | sh -s /tmp/tr3000-backup-XXXX.tar.gz
```

Перед restore: желательно сделать свежий бэкап текущего состояния.

Политика: podkop **только KotiKey**, VPS в main не добавлять — см. `TR3000-FULL-HANDOFF-LOCAL-AGENT.md`.