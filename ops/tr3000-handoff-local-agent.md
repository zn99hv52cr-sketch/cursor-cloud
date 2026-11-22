# Handoff: TR3000 podkop + HDrezka MiTV + доступ Cloud Agent

**Полная версия (бэкап + iOS + всё):** [`TR3000-FULL-HANDOFF-LOCAL-AGENT.md`](./TR3000-FULL-HANDOFF-LOCAL-AGENT.md)

Контекст для **локального агента** (LAN SSH или когда `ssh -p 2222 root@100.81.160.52` с tailnet работает).

## Цели

1. **MiTV Box** (`192.168.2.145`, MAC `9c:9d:07:d5:e6:54`): HDrezka — поиск/метаданные ок, **постеры серые**, **видео обязательно через voidboost/direct** (не ломать).
2. **Podkop/sing-box** на TR после ребута и правок: VPN, fakeip DNS `127.0.0.42`, сплит маршрутизация.
3. **Постоянный доступ Cloud Agent** по `ssh -p 2222` на Tailscale IP (не порт 22 / Tailscale SSH).

## Устройство

| Параметр | Значение |
|----------|----------|
| Роутер | Cudy TR3000, hostname `cudy-tr3000` |
| Tailscale IPv4 | `100.81.160.52` |
| LAN | `192.168.2.1` |
| MagicDNS на роутере | **не включать** |
| Cloud agent | `cursor-cloud`, ключ `~/.ssh/wr3000p_ed25519`, Host `tr3000` → Port **2222** |
| WR3000P | `100.104.207.62:2222` — **другая сеть**, к `192.168.2.1` не достучаться |

## Symptom: постеры MiTV

- **voidboost/stream** должны оставаться в **`podkop.hdrezka_direct`** (connection_type `exclusion` → WAN direct).
- CDN постеров **`st.hdrezka.ac`**, **`static.hdrezka.ac`**, postimg, **`hdrzk.org`** — через **`podkop.main`** (VPN) + **`podkop.main.user_subnets`**: `179.43.0.0/16`, `82.221.0.0/16`, `195.154.239.0/24`, `185.231.220.9/32`.
- MiTV может ходить на CDN **по IP** (DoH) — нужны **user_subnets** и **nft mangle** на `@podkop_subnets` и `198.18.0.0/15`.

## Root cause 1: пустой nft mangle после boot/restart

- **`/usr/bin/podkop` `start_main`**: `create_nft_rules` **до** **`/usr/bin/podkop-tun-up`**.
- Кастомный **`podkop-tun-up`** делает `nft flush chain ... mangle/proxy` и **не восстанавливает** правила.
- Итог: трафик LAN к `179.43.x` и fakeip уходит в **eth0**, постеры не грузятся.

**Фикс (на роутере):**

- Скрипт **`/usr/bin/podkop-restore-mangle.sh`** (в репо `ops/scripts/tr3000-podkop-restore-mangle.sh`).
- В конец **`/usr/bin/podkop-tun-up`**: строка `/usr/bin/podkop-restore-mangle.sh`.

Проверка:

```sh
nft list chain inet PodkopTable mangle | grep counter
ip route get 179.43.158.226 from 192.168.2.145 iif br-lan   # должно быть dev sbtun
ip route get 198.18.0.15 from 192.168.2.145 iif br-lan
```

## Root cause 2: гонка при boot — `tr3000-wan-recover`

- Порядок: `S99podkop` → … → `S99usb-vpn-start` → **`tr3000-wan-recover boot`**.
- Старый wan-recover: если **sing-box уже есть** → **`podkop reload`** (stop, flush nft, stop sing-box, start снова) + снова **tun-up** (flush mangle).

**Фикс:** `ops/scripts/tr3000-wan-recover.sh` → `/usr/bin/tr3000-wan-recover`:

- На **`boot`**: не вызывать `reload`; ждать/один раз `podkop start`.
- Если sing-box/sbtun на месте: только **`podkop-tun-up`** + **`podkop-restore-mangle.sh`**.

## Root cause 3: `podkop status` = not running

- Procd: `command /usr/bin/podkop start` — **one-shot**, exit 0 → **`running: false`**.
- Реальный демон: **`sing-box`**. Проверка: `pidof sing-box`.

## Доступ Cloud Agent

### Что ломалось

- Tailscale **`:22`**: RunSSH, 502 / нужен клик `/a/...` — облаку не подходит.
- **`:2222` dropbear**: после скрипта fix был **`/etc/init.d/tailscale restart`** → podkop/DNS падали, **2222 на tailscale переставал отвечать** с облака (relay, `rx 0`).
- В админке Tailscale key expiry «4 months» — **не** причина таймаута SSH (отдельно можно Disable key expiry на ПК).

### Скрипт доступа (LAN / LuCI Terminal)

`ops/scripts/tr3000-fix-agent-access-lan.sh` → на роутер:

- Ключ агента в `/etc/dropbear/authorized_keys`
- **`dropbear.alt`**: Port **2222**, Interface **пустой** (все интерфейсы, incl. tailscale0)
- Firewall: **Allow-SSH-2222-Tailscale** (src tailscale → tcp 2222)
- **`tailscale set --ssh=false`** **без** полного restart tailscale (обновлённая версия в репо)

Проверка с телефона (Tailscale):

```sh
ssh -p 2222 root@100.81.160.52
```

### Что уже делали на роутере (когда SSH работал ~15:33 UTC+3)

- Выполнен **`fix-agent-access-lan.sh`** (curl с GitHub).
- Кратко был **AGENT_OK** по `ssh -p 2222` с облака (~12:34 UTC).
- Потом снова таймауты; **mitv-apply** с облака мог не завершиться (долгий `podkop restart`).

## DNS podkop «не резолвит запрещёнку»

После recover: **`sing-box=1`**, **`mangle_rules=4`**, но **`nslookup instagram.com 127.0.0.42`** пустой.

**Скрипт:** `ops/scripts/tr3000-podkop-dns-fix.sh`

- dnsmasq → `server=127.0.0.42#53`, noresolv
- restart sing-box или podkop start
- tun-up + restore-mangle, dnsmasq restart
- VERIFY: instagram/chatgpt → **198.18.x**

Общий recover: `ops/scripts/tr3000-podkop-recover.sh`.

## HDrezka MiTV — один прогон

`ops/scripts/tr3000-hdrezka-mitv-apply.sh`:

- poster domains в **main**, убрать из **hdrezka_direct**
- DHCP option **6,192.168.2.1** для MiTV host
- `podkop restart` + **restore-mangle**
- VERIFY в stdout

Деплой с машины с SSH:

`ops/scripts/tr3000-push-and-apply.sh`

## Скрипты в репо (ветка `cursor/fi-vps-outage-runbook-dead`)

| Файл | Назначение |
|------|------------|
| `ops/scripts/tr3000-fix-agent-access-lan.sh` | 2222 + firewall + RunSSH off |
| `ops/scripts/tr3000-podkop-restore-mangle.sh` | nft mangle после tun-up |
| `ops/scripts/tr3000-wan-recover.sh` | boot без podkop reload |
| `ops/scripts/tr3000-podkop-recover.sh` | поднять sing-box + dnsmasq |
| `ops/scripts/tr3000-podkop-dns-fix.sh` | починить 127.0.0.42 |
| `ops/scripts/tr3000-hdrezka-mitv-apply.sh` | постеры + MiTV DHCP |
| `ops/scripts/tr3000-push-and-apply.sh` | залить всё с агента по SSH |
| `ops/tr3000-agent-access.md` | runbook доступа |
| `ops/tr3000-podkop-boot.md` | runbook reboot |
| `ops/tr3000-hdrezka-mitv-posters.md` | runbook постеров |

Raw URL шаблон:

```text
https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts/<имя>.sh
```

На роутере (LAN):

```sh
curl -fsSL "<url>" | sh
```

## Рекомендуемый порядок для локального агента

1. `ssh root@192.168.2.1` или `ssh -p 2222 root@100.81.160.52` (с tailnet).
2. `tr3000-fix-agent-access-lan.sh` (если облаку нужен 2222).
3. `tr3000-podkop-dns-fix.sh` — пока нет `198.18.x` на `nslookup instagram.com 127.0.0.42`.
4. `tr3000-hdrezka-mitv-apply.sh`.
5. Проверки:

```sh
pidof sing-box
nft list chain inet PodkopTable mangle | grep counter
nslookup instagram.com 127.0.0.42
nslookup st.hdrezka.ac 127.0.0.42
nslookup hdrzk.org 127.0.0.42
uci get podkop.main.user_domains | tr " " "\n" | grep -E "st\.hdrezka|hdrzk"
uci get podkop.hdrezka_direct.user_domains | tr " " "\n" | grep voidboost
logread | grep tr3000-wan-recover | tail -5   # boot: skip reload, не "podkop reload"
```

6. На MiTV: force stop HDrezka → поиск снова.

## Состояние на момент handoff (~22 ноя 2026, вечер MSK)

- Cloud Agent: **часы** таймаутов **`ssh -p 2222`**, Tailscale **relay fra/hel, rx 0** периодически.
- Пользователь: Termius **root@Cudy** (LAN/Tailscale), прогонял **recover**; **dns-fix** — следить за опечаткой в имени файла (`dns-fix.sh`, не `dns-fix-k.sh`).
- Таймер подписки `tr3000-retry-apply` на Cloud Agent **отключён** (спам каждые 10 мин).

## Чего не делать

- Не убирать **voidboost** / **stream.voidboost.*** из `hdrezka_direct`.
- Не добавлять poster CDN в `hdrezka_direct` (старый `tr3000-hdrezka-posters-fix.sh` — устарел).
- Не делать полный **`/etc/init.d/tailscale restart`** в routine fix (роняет podkop и 2222).
- Не полагаться на `/etc/init.d/podkop status` — смотреть **`pidof sing-box`** и mangle counters.