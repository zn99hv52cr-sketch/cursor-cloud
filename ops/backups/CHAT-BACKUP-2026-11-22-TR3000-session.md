# Полный бэкап чата Cloud Agent — TR3000 (22 ноя 2026, ~15:00–01:30 MSK)

Сессия: podkop, MiTV HDrezka, iPhone Wi‑Fi, SSH с облака, USB-бэкап, handoff для локального агента.

---

## 1. Железо и доступ

| Узел | Значение |
|------|----------|
| Cudy TR3000 | LAN `192.168.2.1`, hostname `cudy-tr3000`, OpenWrt 25.12 |
| Tailscale TR | `100.81.160.52` |
| Cloud Agent | `cursor-cloud` `100.66.76.102`, ключ `~/.ssh/wr3000p_ed25519`, **SSH порт 2222** |
| WR3000P | `100.104.207.62:2222` — **другая сеть** |
| MiTV | `192.168.2.145`, MAC `9c:9d:07:d5:e6:54` |
| iPhone (ист.) | `192.168.2.195` — смотреть dhcp.leases |
| Podkop DNS | `127.0.0.42` → dnsmasq только туда |
| **USB бэкап** | **`/mnt/usb/backups/`**, KotiKey: **`koty-k-kotikey/urltest-preferred.links`** |

**Политика podkop:** исходящий **только KotiKey**, **без VPS/FI** в `podkop.main`.

**ПК пользователя:** HAPP **включён**, отключать **не будет** (только ПК).

**Телефон:** только **iOS**, VPN-профилей **нет** (по словам пользователя).

---

## 2. Root cause (уже известные баги)

### A. Пустой nft mangle
`podkop-tun-up` делает flush mangle/proxy и не восстанавливает → LAN в eth0.
**Фикс:** `/usr/bin/podkop-restore-mangle.sh` в конец `podkop-tun-up`.

### B. Boot `tr3000-wan-recover`
При boot вызывал `podkop reload` → гонка с S99podkop.
**Фикс:** `tr3000-wan-recover.sh` — на boot без reload.

### C. Tailscale / SSH с облака
**Нельзя:** `/etc/init.d/tailscale restart`, `tailscale up --ssh`, тяжёлый `podkop restart` в routine.
**Нужно:** dropbear **:2222**, `tailscale set --ssh=false`.
**:22** на tailnet → RunSSH 502.

### D. Путь cloud ↔ TR
- Днём: ping через DERP **OK**, SSH **:2222 timeout**.
- TR → `ping 100.66.76.102` **timeout**.
- С **ПК** заход **`:2222` работал**.
- Вечером (~23:07 MSK): ping **тоже timeout** — TR **не отвечает** в tailnet с облака.

### E. HDrezka MiTV
Постеры: **main** + subnets; **voidboost/stream** — только **hdrezka_direct** (WAN).

### F. iPhone Wi‑Fi
На роутере instagram → **198.18.x**, sing-box ok; с iPhone **не грузит** (открыто).
Гипотезы: DNS не `192.168.2.1`, iCloud Private Relay, IPv6/QUIC/DoT обход.
Скрипты: `tr3000-ios-wifi-fix.sh`, `tr3000-ios-wifi-diag.sh`.

---

## 3. Что делали в чате (хронология)

1. MiTV постеры серые; podkop после ребута; cloud SSH.
2. Скрипты: restore-mangle, wan-recover, dns-fix, emergency-up, agent-access-permanent, hdrezka-mitv-apply, phone-wifi-dns, ios-wifi-fix/diag.
3. Пользователь **с ПК** зашёл на `:2222`; phone-wifi-dns дал sing-box + fakeip + mangle counters.
4. iPhone — ярость; пользователь сказал **СТОП**.
5. **TR3000-FULL-HANDOFF-LOCAL-AGENT.md** + backup scripts; правка **KotiKey only**.
6. Пользователь: **бэкап на флешке** — `tr3000-export-usb-backup.sh`, `tr3000-restore-from-usb.sh`.
7. Облако не достучалось; пользователь на **LTE без Wi‑Fi**.
8. Объяснение relay vs SSH; потом снова **ping+ssh fail**.
9. Пользователь дал runbook: `tr3000-boot-stable.sh`, pin **`main-5-out`**, `ig=200` — скрипт добавлен в репо, **с облака не выполнен**.

---

## 4. НЕЗАКРЫТЫЕ ВОПРОСЫ (критично)

| # | Проблема | Статус |
|---|----------|--------|
| 1 | **iPhone iOS на домашнем Wi‑Fi** — запрещёнка не грузит | **Не решено** (диагностика не завершена; пользователь на LTE) |
| 2 | **MiTV HDrezka постеры в поиске** | **Не проверено** после полного apply |
| 3 | **Cloud Agent SSH `100.81.160.52:2222`** | **Не работает** (вечером и ping мёртв) |
| 4 | **TR online в Tailscale на телефоне пользователя** | **Не ответил** (online/offline) |
| 5 | **Доставить USB-бэкап / чат в Telegram** | **Не сделано агентом** (нет BOT_TOKEN); пользователь должен `tr3000-send-backup-telegram.sh` с FI VPS |
| 6 | **`ig=200` + main-5-out** после `tr3000-boot-stable.sh` | **Не прогнано** (нет SSH) |
| 7 | **Почему relay cloud↔TR ломается стабильно** | Диагностика частичная; **постоянный фикс** (direct / reverse SSH) **не внедрён** |
| 8 | **`CUDY_TR3000_SSH_KEY`** в облаке | **unset** — использовался `wr3000p_ed25519` |

---

## 5. Репозиторий (ветка `cursor/fi-vps-outage-runbook-dead`)

**Главный handoff:** `ops/TR3000-FULL-HANDOFF-LOCAL-AGENT.md`

**Raw GitHub:**
```
https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/TR3000-FULL-HANDOFF-LOCAL-AGENT.md
https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/backups/CHAT-BACKUP-2026-11-22-TR3000-session.md
```

### Скрипты (имена)
| Скрипт | Назначение |
|--------|------------|
| `tr3000-backup-full.sh` | UCI+nft+kotikey с USB |
| `tr3000-export-usb-backup.sh` | Упаковать **флешку** → `/tmp/...tar.gz` |
| `tr3000-restore-from-usb.sh` | KotiKey с USB → UCI |
| `tr3000-restore-from-backup.sh` | Из tarball |
| `tr3000-send-backup-telegram.sh` | FI VPS → TG chat `186409737` |
| `tr3000-boot-stable.sh` | DNS+podkop+mangle, **main-5-out**, `ig=200` |
| `tr3000-emergency-up.sh` | Авария |
| `tr3000-podkop-restore-mangle.sh` | nft mangle |
| `tr3000-wan-recover.sh` | boot без reload |
| `tr3000-ios-wifi-fix.sh` / `-diag.sh` | iPhone |
| `tr3000-hdrezka-mitv-apply.sh` | Постеры MiTV |
| `tr3000-agent-access-permanent.sh` | :2222 |

**Шаблон URL скриптов:**
```
https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/<имя>.sh
```

---

## 6. Команды подключения (от пользователя)

```sh
ssh -p 2222 -o StrictHostKeyChecking=no -i "$CUDY_TR3000_SSH_KEY" root@100.81.160.52
# fallback:
tailscale ssh root@100.81.160.52
```

На Cudy после входа:
```sh
uptime
/usr/bin/tr3000-boot-stable.sh
nslookup instagram.com 192.168.2.1
curl -4 -m15 -o /dev/null -w 'ig=%{http_code}\n' https://www.instagram.com/
```

USB → TG:
```sh
wget -qO- ".../tr3000-export-usb-backup.sh" | sh
# scp на VPS → CHAT_ID=186409737 tr3000-send-backup-telegram.sh
```

---

## 7. Промпт для локального Cursor

```text
Continue TR3000 from @ops/TR3000-FULL-HANDOFF-LOCAL-AGENT.md and @ops/backups/CHAT-BACKUP-2026-11-22-TR3000-session.md
branch cursor/fi-vps-outage-runbook-dead.
SSH: root@192.168.2.1 or ssh -p 2222 root@100.81.160.52.
Podkop: KotiKey ONLY, no VPS in main.
Do NOT tailscale restart. Open: iOS WiFi, MiTV posters, cloud SSH, boot-stable ig=200.
USB backup: /mnt/usb/backups/
```

---

## 8. Чего не делать (повтор)

- VPS в podkop main
- voidboost из hdrezka_direct не убирать
- poster CDN в hdrezka_direct не кидать
- tailscale restart / tailscale up --ssh
- путать WR3000P и TR3000

---

## 9. Эмоциональный контекст пользователя

Пользователь **крайне устал** от таймаутов SSH с облака, от инструкций «сам в Termius» и от неработающего iPhone на Wi‑Fi. Просил **СТОП**, потом полный handoff + бэкап + доставку в TG. Ожидание: **агент сам** чинит на роутере — **блокируется tailnet cloud↔TR**.

---

*Конец бэкапа сессии. Сгенерировано Cloud Agent 22.11.2026.*