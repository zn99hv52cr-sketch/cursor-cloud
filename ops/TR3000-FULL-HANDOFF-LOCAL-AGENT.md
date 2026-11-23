# TR3000 — полный handoff для локального агента (22 ноя 2026)

Скопируй в **локальный Cursor** и работай с **LAN SSH** или `ssh -p 2222 root@100.81.160.52` (Tailscale).

---

## 0. Цели (что ещё не доведено до «зелёного»)

| # | Задача | Статус на вечер 22.11 |
|---|--------|------------------------|
| 1 | **MiTV HDrezka**: видео ok, **постеры в поиске серые** | Нужны main + subnets + mangle; voidboost в direct |
| 2 | **Podkop после ребута**: fakeip, VPN, сплит | Частично починено скриптами; boot race в wan-recover |
| 3 | **Cloud Agent SSH** `100.81.160.52:2222` | С **ПК пользователя** заходило; с **cursor-cloud** таймаут (TR не пингует `100.66.76.102`) |
| 4 | **iPhone на Wi‑Fi (iOS)**: запрещёнка не грузится | Роутер резолвит `instagram` → `198.18.x`; на телефоне всё ещё нет. VPN на телефоне **выключен** (по словам пользователя) |

**ПК у пользователя: HAPP включён и отключать не будет** — это только ПК, не телефон.

---

## 1. Топология

| Узел | IP / доступ | Заметки |
|------|-------------|---------|
| Cudy TR3000 | LAN `192.168.2.1`, hostname `cudy-tr3000` | OpenWrt 25.12 |
| Tailscale TR | `100.81.160.52` | MagicDNS **на роутере не включать** |
| Cloud Agent | `cursor-cloud` `100.66.76.102` | SSH ключ `wr3000p_ed25519`, **порт 2222** |
| WR3000P | `100.104.207.62:2222` | **Другая сеть**, не путать с TR |
| MiTV Box | `192.168.2.145` MAC `9c:9d:07:d5:e6:54` | HDrezka |
| iPhone (исторически) | `192.168.2.195` | см. dhcp.leases; IP может измениться |
| Podkop DNS | `127.0.0.42:53` (sing-box) | dnsmasq → только туда |
| Dropbear agent | **TCP 2222** все интерфейсы | **Не порт 22** (Tailscale RunSSH) |

**Публичный ключ агента** (в `/etc/dropbear/authorized_keys`):

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag
```

---

## 2. Архитектура podkop (кратко)

- **Демон:** `sing-box` (`pidof sing-box`). `podkop status` = not running — **норма** (procd one-shot).
- **FakeIP:** `198.18.0.0/15`, DNS `127.0.0.42`.
- **Маркировка:** nft `table inet PodkopTable`, fwmark `0x00100000`, policy routing table `podkop` → `sbtun`.
- **Цепочки:** `mangle` (prerouting), `mangle_output`, `proxy` (tproxy `127.0.0.1:1602`).
- **HDrezka split:**
  - **`podkop.hdrezka_direct` (exclusion):** voidboost*, stream.voidboost.* — **только WAN direct** (видео).
  - **`podkop.main` (VPN):** poster CDN домены + **user_subnets** `179.43.0.0/16`, `82.221.0.0/16`, `195.154.239.0/24`, `185.231.220.9/32`.

### Политика исходящих в podkop (обязательно для агента)

**В podkop на TR3000 только KotiKey — не личный/FI VPS.**

- Исходящий трафик `podkop.main` → **только ноды KotiKey** (`main-1-out` … `main-N-out`, urltest по их link’ам).
- **Нельзя** добавлять в podkop своий VPS (FI Remnawave, AdminVPS, WireGuard на `193.124.224.248`, «домашний» outbound и т.п.) — VPS для **AWG/HAPP/панели/бота**, не для podkop main.
- Список link’ов: `podkop.main.urltest_proxy_links` из **`/mnt/usb/backups/koty-k-kotikey/urltest-preferred.links`** (первые **4** ноды — рабочий компромисс IG/TG; см. `tr3000-fix-instagram.sh`).
- Селектор **`main-out`**: предпочтительно **`main-1-out`**; не подсовывать VPS и не ломать urltest ради HDrezka.
- Проверка после правок:

```sh
uci get podkop.main.urltest_proxy_links | tr ' ' '\n' | head -6
wget -qO- --timeout=3 http://127.0.0.1:9090/proxies/main-out 2>/dev/null | grep -o '"now":"[^"]*"' | head -1
# now должно быть main-*-*-out (KotiKey), не vps/remna/custom
```

---

## 3. Root cause — пустой nft mangle

1. `podkop start` → `create_nft_rules` **до** `podkop-tun-up`.
2. Кастомный **`/usr/bin/podkop-tun-up`** делает `nft flush` mangle/proxy и **не восстанавливает** правила.
3. LAN трафик к CDN и fakeip идёт в **eth0** → постеры/сплит ломаются.

**Фикс:** `ops/scripts/tr3000-podkop-restore-mangle.sh` → `/usr/bin/podkop-restore-mangle.sh`, в конец **`podkop-tun-up`**:

```sh
/usr/bin/podkop-restore-mangle.sh
```

**Проверка:**

```sh
nft list chain inet PodkopTable mangle | grep counter
ip route get 179.43.158.226 from 192.168.2.145 iif br-lan   # dev sbtun, не eth0
ip route get 198.18.0.26 from 192.168.2.195 iif br-lan
```

---

## 4. Root cause — boot `tr3000-wan-recover`

Порядок: `S99podkop` → … → `tr3000-wan-recover boot`.

**Старый баг:** sing-box уже есть → **`podkop reload`** → tear-down, flush nft, гонка с procd.

**Фикс:** `ops/scripts/tr3000-wan-recover.sh` → `/usr/bin/tr3000-wan-recover`

- **boot:** не `reload`; ждать sing-box или один `podkop start`.
- Иначе: только `podkop-tun-up` + `podkop-restore-mangle.sh` если sing-box/sbtun on place.

```sh
logread | grep tr3000-wan-recover | tail -10
# хорошо: "skip podkop reload", "skip reload"
# плохо: "podkop reload"
```

---

## 5. Tailscale / SSH — КРИТИЧНО (пользователь устал от «умирающего SSH»)

### Нельзя в routine-фиксах

- `/etc/init.d/tailscale restart`
- `tailscale up --ssh`
- Полный `/etc/init.d/podkop restart` без необходимости (лучше `podkop start` / `list_update` + tun-up + restore-mangle)

### Нужно

- Dropbear **`dropbear.alt`**: Port **2222**, `Interface=''` (слушает tailscale0).
- Firewall: **Allow-SSH-2222-Tailscale** (src tailscale → 2222 ACCEPT).
- **`tailscale set --ssh=false --accept-risk=lose-ssh`** (без restart tailscaled).

### Симптомы

- Порт **22** на `100.81.160.52` → Tailscale SSH, 502, ссылка `login.tailscale.com/a/...`.
- Cloud Agent после **tailscale restart** часто **relay fra, rx 0** — TCP :2222 таймаут с облака, с ПК в домашней сети может работать.

---

## 6. DNS «не резолвит запрещёнку»

dnsmasq должен смотреть **только** на podkop:

```sh
uci get dhcp.@dnsmasq[0].server   # 127.0.0.42#53
uci get dhcp.@dnsmasq[0].noresolv   # 1
nslookup instagram.com 127.0.0.42   # Address: 198.18.x
```

Скрипт: `tr3000-podkop-dns-fix.sh`, общий: `tr3000-podkop-recover.sh`, аварийный: `tr3000-emergency-up.sh`.

---

## 7. iPhone iOS на Wi‑Fi (открытая проблема)

**Факты с роутера (вечер 22.11):** sing-box работал, instagram → `198.18.0.26`, mangle counters росли с LAN.

**Пользователь:** VPN-профилей на iPhone **нет**. Instagram/запрещёнка **не грузятся**.

### Вероятные причины (проверять по порядку)

1. **DNS не `192.168.2.1`** — Wi‑Fi → DNS вручную, только роутер.
2. **iCloud Private Relay** — не в «VPN», а **Настройки → Apple ID → iCloud → Частный узел** → Выкл.
3. **IPv6 обход** — iOS предпочитает v6; фикс `tr3000-ios-wifi-fix.sh` (отключает RA/DHCPv6, sysctl ipv6, блок QUIC UDP/443 и DoT 853 с LAN).
4. **Неверный IP** в `ip route get ... from` — смотреть `/tmp/dhcp.leases`.
5. **Нода main-out мёртва** — с роутера `curl -4 -m15 -o /dev/null -w "%{http_code}" https://www.instagram.com/` должен быть **200**, иначе чинить VPN, не телефон.

Скрипты:

- `tr3000-ios-wifi-fix.sh` — мягкий apply
- `tr3000-ios-wifi-diag.sh` — диагностика
- `tr3000-phone-wifi-dns.sh` — только DNS/DHCP

После фикса: **Забыть Wi‑Fi** на iPhone, переподключиться.

---

## 8. HDrezka MiTV — постеры

**Не трогать:** voidboost / stream.voidboost.* в `hdrezka_direct`.

**В main:** `st.hdrezka.ac`, `static.hdrezka.ac`, `statichdrezka.ac`, `hdrzk.org`, `i.postimg.cc`, `postimg.cc`, `postimg.top`, `image.tmdb.org`, `hdrezka-home.tv` + subnets выше.

Скрипт: `tr3000-hdrezka-mitv-apply.sh` (на роутере **без** тяжёлого restart где возможно).

На ТВ: force stop приложения HDrezka → поиск снова.

**Устаревший:** `tr3000-hdrezka-posters-fix.sh` (кидал CDN в direct — не использовать).

---

## 9. Все скрипты (ветка `cursor/fi-vps-outage-runbook-dead`)

Raw URL:

```text
https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/<имя>.sh
```

| Скрипт | Назначение |
|--------|------------|
| `tr3000-backup-full.sh` | **Полный бэкап UCI/nft/логов** → `/tmp/tr3000-backup-*.tar.gz` |
| `tr3000-emergency-up.sh` | Авария: podkop + DNS + mangle + 2222 |
| `tr3000-podkop-recover.sh` | Поднять sing-box, DNS, mangle |
| `tr3000-podkop-dns-fix.sh` | 127.0.0.42 + dnsmasq |
| `tr3000-podkop-restore-mangle.sh` | Восстановить nft mangle |
| `tr3000-wan-recover.sh` | Boot/hotplug без podkop reload |
| `tr3000-fix-agent-access-lan.sh` | 2222 + firewall + RunSSH off |
| `tr3000-agent-access-permanent.sh` | То же, постоянный вариант |
| `tr3000-hdrezka-mitv-apply.sh` | Постеры + MiTV DHCP DNS |
| `tr3000-hdrezka-search-posters.sh` | Только poster domains |
| `tr3000-mitv-hdrezka-full.sh` | Расширенный MiTV |
| `tr3000-phone-wifi-dns.sh` | DHCP DNS + redirect 53 |
| `tr3000-ios-wifi-fix.sh` | iOS: IPv6/QUIC/DoT + DNS |
| `tr3000-ios-wifi-diag.sh` | Диагностика iPhone |
| `tr3000-fix-instagram.sh` | Meta/TG домены, urltest (делает **podkop restart** — осторожно) |
| `tr3000-add-chatgpt-domains.sh` | ChatGPT домены в main |
| `tr3000-push-and-apply.sh` | Заливка с машины, у которой SSH на TR |
| `send-tr3000-handoff-telegram.sh` | Отправка этого handoff в TG (нужен BOT_TOKEN) |

Доп. markdown в `ops/`:

- `tr3000-handoff-local-agent.md` — краткая версия
- `tr3000-podkop-boot.md`, `tr3000-hdrezka-mitv-posters.md`, `tr3000-agent-access.md`
- `tr3000-tg-wa-media.md` — WA/TG, MSS 1360, main-1-out, QUIC reject

---

## 10. Полный бэкап (сначала сделай это)

**Источник истины — флешка роутера:** `/mnt/usb/backups/` (в т.ч. **`koty-k-kotikey/urltest-preferred.links`**). Там уже лежит рабочий бэкап; cloud agent к флешке **не подключался** — только упакуй и скинь в TG.

Упаковка для отправки: `tr3000-export-usb-backup.sh` (берёт готовый `.tar.gz` с USB **или** пакует всё дерево `backups/`).

На роутере (Termius `root@Cudy`):

```sh
wget -qO- "https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/tr3000-backup-full.sh" | sh
```

Скопировать на ПК:

```sh
scp root@192.168.2.1:/tmp/tr3000-backup-*.tar.gz .
```

Восстановление: `ops/scripts/tr3000-restore-from-backup.sh` — см. `ops/backups/TR3000-RESTORE-README.md`.

**В Telegram бота** (FI VPS, токен в `/opt/vpn-bot/.env`):

```sh
CHAT_ID=186409737 /path/tr3000-send-backup-telegram.sh /tmp/tr3000-backup-*.tar.gz
```

Или через Tailscale:

```sh
scp -P 2222 root@100.81.160.52:/tmp/tr3000-backup-*.tar.gz .
```

---

## 11. Рекомендуемый порядок для локального агента

1. **Бэкап:** `tr3000-backup-full.sh`.
2. SSH: `root@192.168.2.1` или `ssh -p 2222 root@100.81.160.52`.
3. Убедиться: `podkop-tun-up` вызывает `podkop-restore-mangle.sh` (grep в конце файла).
4. Положить актуальные скрипты с GitHub или `tr3000-push-and-apply.sh` с ПК.
5. Если DNS пустой: `tr3000-podkop-dns-fix.sh`.
6. Если после ребута: `tr3000-wan-recover.sh` на `/usr/bin/tr3000-wan-recover` + прогнать вручную: `tr3000-wan-recover boot` **не делать reload** — смотреть logread.
7. **MiTV:** `tr3000-hdrezka-mitv-apply.sh`.
8. **iPhone:** `export IPHONE_IP=<из Wi‑Fi>` → `tr3000-ios-wifi-fix.sh` → `tr3000-ios-wifi-diag.sh`.
9. **Agent 2222:** `tr3000-agent-access-permanent.sh` если облаку нужен доступ.
10. Финальные проверки:

```sh
pidof sing-box
nslookup instagram.com 127.0.0.42
nslookup st.hdrezka.ac 127.0.0.42
nft list chain inet PodkopTable mangle | grep counter
curl -4 -sS -m 15 -o /dev/null -w "ig=%{http_code}\n" https://www.instagram.com/
uci get podkop.hdrezka_direct.user_domains | tr ' ' '\n' | grep voidboost | head -3
netstat -lnpt | grep 2222
tailscale set --ssh=false --accept-risk=lose-ssh
```

---

## 12. Чего не делать (ещё раз)

- **Не добавлять свой VPS в podkop** — только **KotiKey** в `main` / urltest.
- Не переносить poster CDN в `hdrezka_direct`.
- Не выкидывать voidboost из `hdrezka_direct`.
- Не `tailscale restart` в скриптах восстановления.
- Не верить `podkop status` — смотреть `sing-box` и mangle.
- Не путать WR3000P и TR3000.
- Опечатка в URL: `tr3000-podkop-dns-fix.sh`, **не** `dns-fix-k.sh`.

---

## 13. Отправка этого текста в Telegram

Облачный агент **не имеет** `BOT_TOKEN` на VM.

**Вариант A — с FI VPS** (где `/opt/vpn-bot/.env`):

```sh
curl -fsSL "https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/send-tr3000-handoff-telegram.sh" -o /tmp/send-tg.sh
chmod +x /tmp/send-tg.sh
CHAT_ID=186409737 /tmp/send-tg.sh
```

**Вариант B — с ПК пользователя** (если есть токен бота в env):

```sh
export BOT_TOKEN=... CHAT_ID=186409737
bash send-tr3000-handoff-telegram.sh
```

**Вариант C — вручную:** открыть в браузере/GH:

```text
https://github.com/zn99hv52cr-sketch/cursor-cloud/blob/cursor/fi-vps-outage-runbook-dead/ops/TR3000-FULL-HANDOFF-LOCAL-AGENT.md
```

и переслать себе в Telegram / Saved Messages.

---

## 14. Промпт для локального Cursor

```text
Continue TR3000 from @ops/TR3000-FULL-HANDOFF-LOCAL-AGENT.md (branch cursor/fi-vps-outage-runbook-dead).
SSH: root@192.168.2.1 or ssh -p 2222 root@100.81.160.52.
Do NOT tailscale restart, do NOT tailscale up --ssh, avoid podkop restart.
Podkop main outbound: KotiKey ONLY — never add user's FI/VPS nodes to podkop.
Priorities: (1) iOS WiFi blocked sites, (2) MiTV HDrezka posters, (3) stable cloud agent :2222.
Always run tr3000-backup-full.sh before invasive changes.
```

---

## 15. Состояние сессии cloud agent (22.11.2026 ~20:45 MSK)

- Пользователь заходил на Cudy с **ПК** по `100.81.160.52:2222`.
- Прогонял `tr3000-phone-wifi-dns.sh`: sing-box ok, instagram fakeip ok, mangle counters есть.
- `tailscale ping 100.66.76.102` с TR → **timeout** (облако не достучалось обратно).
- Пользователь остановил дальнейшие попытки (**«СТОП»**).
- iPhone: без VPN-профилей, контент на Wi‑Fi не грузится — **не закрыто**.

Конец handoff.