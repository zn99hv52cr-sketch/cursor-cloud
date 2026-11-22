# TR3000 — podkop после ребута

## Пустая таблица маршрутов `podkop` (22.11.2026)

Симптом: DNS **работает** (`instagram.com` → `198.18.x`), но IG/YT/TG **таймаутят** и с роутера, и с устройств.

Причина: в таблице `podkop` остаётся только `local default dev lo`. Правило `105: from all fwmark 0x100000 lookup podkop` не находит маршрут, помеченный трафик уходит в WAN и режется провайдером.

Проверка и фикс:

```sh
ip route show table podkop        # должно быть default dev sbtun + 198.18.0.0/15
/usr/bin/podkop-restore-table.sh  # ops/scripts/tr3000-podkop-restore-table.sh
```

Скрипт дописан в конец `/usr/bin/podkop-tun-up` и в cron (каждые 3 мин, если в таблице меньше 3 строк).

**Не путать** с пустым nft mangle (`podkop-restore-mangle.sh`) — там ломаются счётчики, а не маршруты.

## Симптом

`/etc/init.d/podkop status` → **not running**, хотя VPN «вроде живёт» или, наоборот, постеры/сплит туннель сломаны.

## Почему status врёт

`podkop` в procd — **one-shot**: `command /usr/bin/podkop start` **завершается** после конфигурации. **Демон** — `sing-box`. Проверка:

```sh
pidof sing-box && echo ok
ubus call service list '{"name":"podkop"}' | grep running
```

`exit_code: 0` + `running: false` — **норма**, не значит «podkop не поднялся».

## Почему после ребута ломалось (root cause)

1. **Порядок S99:** `S99podkop` (procd → `podkop start`) → … → `S99usb-vpn-start` ждёт WAN → **`tr3000-wan-recover boot`**.
2. К моменту WAN **sing-box уже поднят** первым стартом.
3. Старый wan-recover: `sing-box есть` → **`podkop reload`** → stop (flush nft, stop sing-box) → start снова + **`podkop-tun-up` flush mangle**.
4. Итог: лишний tear-down, гонки, **пустой nft mangle** (см. `tr3000-podkop-restore-mangle.sh`).

Логи:

```text
tr3000-wan-recover: start reason=boot
tr3000-wan-recover: podkop reload
podkop: Stopping the podkop
podkop: Flush nft
```

## Фикс

Скрипт `ops/scripts/tr3000-wan-recover.sh` → `/usr/bin/tr3000-wan-recover`:

- **boot:** дождаться sing-box от S99podkop или один раз `podkop start`; **никогда** `reload`.
- **hotplug WAN:** если sing-box/sbtun на месте — только **`podkop-tun-up`** + **`podkop-restore-mangle.sh`**, без reload.

Деплой с ПК:

```sh
scp ops/scripts/tr3000-wan-recover.sh root@192.168.2.1:/usr/bin/tr3000-wan-recover
ssh root@192.168.2.1 chmod +x /usr/bin/tr3000-wan-recover
```

## Дополнительно

| Компонент | Роль |
|-----------|------|
| `podkop-guard` | перезапуск если sing-box умер / нет sbtun |
| `podkop-tun-watch` | чинит маршрут `198.18.0.0/15` → sbtun |
| `podkop-tun-up` | flush mangle — нужен хвост `podkop-restore-mangle.sh` |

Полный цикл проверки после ребута:

```sh
pidof sing-box
nft list chain inet PodkopTable mangle | grep counter
ip route get 198.18.0.15 from 192.168.2.145 iif br-lan
```