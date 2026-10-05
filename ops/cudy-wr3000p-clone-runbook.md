# Локальный агент: Cudy WR3000P = клон TR3000

Задача: прошить **новый Cudy WR3000P v1** официальным OpenWrt **25.12.5** (как у домашнего TR3000) и перенести на него **тот же split-tunnel**, что уже работает на TR3000 (`100.81.160.52`, hostname Tailscale `cudy`). Плюс Tailscale, WOL и отдельная подписка Remnawave.

Не импровизируй образы и не копируй чужой VLESS. Секреты (Wi‑Fi PSK, VLESS, JWT, Tailscale auth key) **не писать в git и не печатать в отчёт**.

Эталон живой: Tailscale `100.81.160.52` / LAN `192.168.2.1`. Заметки по нему (если ветка доступна): `ops/cudy-tr3000-podkop-tailscale.md`.

## Жёсткие запреты

1. Образ только **`cudy_wr3000p-v1`**. Не WR3000, не WR3000E/H/S, не TR3000.
2. **Не прошивать `*-ubootmod-*`.** На стоке другой layout, ubootmod без предварительной конвертации ломает загрузчик.
3. Первым файлом в стоковый веб Cudy **не** заливать официальный sysupgrade с downloads.openwrt.org. Сначала промежуточная прошивка Cudy (снятие подписи), потом официальный sysupgrade.
4. Серийник **2543 и новее** (неделя 43 2025 и позже, flash ESMT `F50L1G41LC`): старый intermediate Cudy и OpenWrt **старше 24.10.5** не ставить. Цель — **25.12.5**, intermediate — новый файл с Google Drive Cudy именно для WR3000P.
5. Не включать Tailscale Funnel. На агенте, который ходит на роутеры, `tailscale up --accept-routes=false`.
6. Не включать MagicDNS на роутере (`CorpDNS=false`). Ходить по IP `100.x`, не по имени MagicDNS.
7. `sing-box` в UCI оставить `enabled=0`. Его поднимает podkop. Не включать оба.
8. IPv6 на LAN/WAN не включать.
9. Не добавлять в podkop весь суффикс `blizzard.com` и CDN ниже.
10. Подписку `Cuddy_TR3000` на новый роутер **не** переносить. Создать отдельного пользователя.

## 0. Доступ

VPS (создание подписки, не для прошивки):

```bash
sshpass -e ssh -o StrictHostKeyChecking=no root@193.124.224.248
```

`SSHPASS` уже в окружении облака/локального агента, если его прокинули. Токен панели: `/root/creds/remnawave-vpn-bot.jwt` на VPS. Не выводить.

TR3000:

```bash
tailscale up --auth-key="$TS_AUTHKEY" --hostname=cursor-agent --accept-routes=false --ssh
ssh root@100.81.160.52
```

Первый SSH за сессию может напечатать `To authenticate, visit: https://login.tailscale.com/a/...`. Это проверка Tailscale SSH, не меню Machines. Пользователь открывает URL один раз.

Снять эталон (секреты не в git):

```bash
mkdir -p /tmp/tr3000-ref
ssh root@100.81.160.52 'opkg list-installed; echo ====; uci show network; echo ====; uci show firewall; echo ====; uci show dhcp; echo ====; uci show wireless; echo ====; uci show podkop; echo ====; uci show tailscale; echo ====; uci show sing-box; echo ====; ls /etc/dnsmasq.d /etc/sysctl.d; echo ====; cat /etc/sysctl.d/99-disable-ipv6.conf; echo ====; cat /etc/dnsmasq.d/vpn2-newip.conf; echo ====; df -h; echo ====; ubus call system board' > /tmp/tr3000-ref/dump.txt
```

`wireless` и `podkop.main.proxy_string` содержат секреты. Файл оставить только локально.

## 1. Подписка Remnawave `cudy wr3000p`

Пользователь в панели: **`cudy_wr3000p`** (пробел API обычно не принимает). `description`: `cudy wr3000p`. Сквад как у домашнего роутера: **Default-Squad** `8bade8f0-7d9b-44a9-86de-b0aab9a41501`. Лимит трафика 0, стратегия `NO_RESET`, expire `2099-12-31`, status `ACTIVE`.

На VPS:

```bash
TOKEN=$(cat /root/creds/remnawave-vpn-bot.jwt)
# если username уже есть — не создавать второго, использовать его
curl -sk --resolve vpn2.sharpmaind.ru:443:127.0.0.1 \
  -H "Authorization: Bearer $TOKEN" \
  -o /tmp/rw-user.json -w "%{http_code}\n" \
  https://vpn2.sharpmaind.ru/api/users/by-username/cudy_wr3000p
```

Если не 200:

```bash
curl -sk --resolve vpn2.sharpmaind.ru:443:127.0.0.1 \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -o /tmp/rw-user.json -w "%{http_code}\n" \
  -X POST https://vpn2.sharpmaind.ru/api/users \
  -d '{"username":"cudy_wr3000p","status":"ACTIVE","trafficLimitBytes":0,"trafficLimitStrategy":"NO_RESET","expireAt":"2099-12-31T00:00:00.000Z","description":"cudy wr3000p","activeInternalSquads":["8bade8f0-7d9b-44a9-86de-b0aab9a41501"]}'
```

Проверить в ответе `activeInternalSquads[0].name == Default-Squad`. Сохранить `subscriptionUrl` в `/root/creds/cudy-wr3000p-sub.url` (права 600). В отчёт писать только username и HTTP-код.

Подписка: `https://vpn2.sharpmaind.ru/api/sub/<shortUuid>`.

Для podkop нужен **один** исходящий, как на TR3000, не весь список профилей:

- протокол VLESS, transport **ws**, path **`/vpn`**, port **443**
- security **tls**, sni/host **`vpn2.sharpmaind.ru`**, fp **chrome**
- address в ссылке может быть IP; на роутере всё равно pin DNS на `185.141.217.43`

Скачать подписку на VPS и вытащить строку с `type=ws` и `path=%2Fvpn` (или `path=/vpn`). Сохранить в `/root/creds/cudy-wr3000p-vless.url` (600). Не логировать URI.

Рабочий публичный IP для RU-клиентов: **`185.141.217.43`**. Старый `193.124.224.248` из RU не открывается, в подписку и dnsmasq его не подставлять.

## 2. Прошивка WR3000P

Железо на столе, ПК кабелем в **LAN**, не в WAN. Сверить наклейку: модель **WR3000P**, variant **v1**. Записать SN.

Файлы:

- Промежуточный OpenWrt **от Cudy** для WR3000P (веб стока → снятие подписи): https://www.cudy.com/en-us/blogs/faq/openwrt-software-download → Google Drive, каталог WR3000P, **новый** intermediate, если SN ≥ 2543.
- Официальный sysupgrade (второй шаг, уже из OpenWrt, **Keep settings выключен**):

`https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-25.12.5-mediatek-filogic-cudy_wr3000p-v1-squashfs-sysupgrade.bin`

Перед заливкой сверить SHA256 с `profiles.json` того же релиза (`images[].sha256` у `cudy_wr3000p-v1`, type `sysupgrade`). Имя файла обязано содержать `cudy_wr3000p-v1-squashfs-sysupgrade.bin` и **не** содержать `ubootmod`.

Порядок:

1. Стоковый веб обычно `http://192.168.10.1` → System / Firmware. Залить **только** intermediate Cudy. Дождаться ребута.
2. OpenWrt поднимется на `192.168.1.1` (пароль пустой). LuCI → System → Backup / Flash Firmware → Flash image → официальный sysupgrade 25.12.5. Галка **Keep settings снята**.
3. После ребута:

```bash
. /etc/openwrt_release
echo "$DISTRIB_RELEASE $DISTRIB_TARGET"
cat /tmp/sysinfo/board_name
# ждём: 25.12.5  mediatek/filogic  и  cudy,wr3000p-v1
df -h /overlay
```

4. Если overlay **меньше ~80 МБ свободно** до установки sing-box и tailscale — **остановиться и написать пользователю**. На TR3000 эти два пакета занимают десятки МБ (`sing-box` ~42 МБ, `tailscaled` ~25 МБ) и забили overlay на 90%. ubootmod ради места сам не делать.
5. Задать пароль root. WAN-порт в провайдера пока не обязателен, но для `opkg` и подписки нужен интернет.

Если после стокового шага роутер не поднимается: recovery TFTP по инструкции Cudy для этой модели. Не переходить на ubootmod «чтобы оживить».

## 3. Пакеты

Сравнить `opkg list-installed` эталона и поставить то, без чего клон не работает:

- `podkop` и `luci-app-podkop` (репозиторий itdog: скрипт `https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh`; версию по возможности как на TR3000, `opkg info podkop`)
- `sing-box` (ставит podkop; UCI `enabled=0`)
- `tailscale` / `luci-app-tailscale`, если пакет так назван на эталоне
- WOL: `etherwake` и `luci-app-wol` — **поставить даже если на TR3000 пакета нет** (пользователь явно просил WOL). Если на эталоне есть ещё `luci-app-wol` или `etherwake-nfqueue`, повторить то же имя.

Дальше не ставить лишнего: на слабом flash каждый `opkg upgrade` опасен. После установки снова `df -h /overlay`.

## 4. Сеть, Wi‑Fi, IPv6

Роль: замена домашнего TR3000 (LAN `192.168.2.1/24`). **Пока новый роутер не в том же LAN, что TR3000.** Два DHCP `192.168.2.1` одновременно не держать. Cutover: выключить TR3000, включить WR3000P в WAN провайдера и LAN квартиры.

Снять с эталона и перенести смыслом, не слепым `uci import` всего файла (там чужие MAC и имя интерфейсов; на filogic сверить `ip link`):

- LAN `192.168.2.1/24`, DHCP как на TR3000
- WAN DHCP, firewall zone wan input REJECT, masquerade, MTU fix если он есть на эталоне
- Wi‑Fi 2.4 и 5: те же SSID и PSK, что `uci show wireless` на TR3000 (WPA2-PSK). Каналы можно оставить auto, если радио wr3000p называется иначе — править только `device`, SSID/key скопировать
- hostname роутера: `cudy-wr3000p`

IPv6 выключить так же, как на TR3000 2026-10-04:

- удалить `network.wan6` и ULA prefix, если мастер их создал
- `lan` и `wan`: `delegate=0`, `ipv6=0`
- убрать из firewall разрешения DHCPv6 / MLD / ICMPv6 и `wan6` из зоны wan
- положить `/etc/sysctl.d/99-disable-ipv6.conf` копией с TR3000
- `sysctl -p` этот файл

`odhcpd` можно `disable` и `stop`, если RA/DHCPv6 уже выключены.

## 5. dnsmasq pin vpn2

Иначе podkop может уйти на старый IP.

`/etc/dnsmasq.d/vpn2-newip.conf`:

```
address=/vpn2.sharpmaind.ru/185.141.217.43
```

В dhcp/dnsmasq, как на эталоне: DNS клиентов уходит в sing-box `127.0.0.42` (это делает podkop). Не ломать этот redirect своим `server=`.

```bash
/etc/init.d/dnsmasq restart
nslookup vpn2.sharpmaind.ru 127.0.0.1
# должен быть 185.141.217.43 до включения podkop; после podkop доменные правила могут отвечать 198.18.x.x — это нормально для списка туннеля
```

## 6. podkop = те же маршруты, что TR3000

Источник правды — `uci show podkop` с `100.81.160.52`, не сокращённый список из памяти.

Перенести:

- `podkop.main.user_domains` целиком (`uci get` / `add_list`), включая уже имеющиеся rutracker, rutor, nnmclub, cursor*, anydesk, rezka/voidboost, hp* и набор Battle.net
- остальные опции podkop (режим tun/fakeip, интерфейс, dns), кроме `proxy_string`

Обязательный набор Battle.net (если вдруг выпал при копировании):

`battle.net`, `battlenet.com`, `diabloimmortal.com`, `blz-contentstack.com`, `blznav.akamaized.net`, `blzmedia-a.akamaihd.net`, `bnetcmsus-a.akamaized.net`, `bnetproduct-a.akamaized.net`, `bnetshopus.akamaized.net`, `blizzcon-a.akamaihd.net`, `news.blizzard.com`, `static.blizzard.com`, `www.blizzard.com`, `eu.blizzard.com`, `us.blizzard.com`, `di.blizzard.com`, `diabloimmortal.blizzard.com`

**Не добавлять:** `blizzard.com` целиком, `level3.blizzard.com`, `*.cdn.blizzard.com`, `blzddist1-a.akamaihd.net`, `blzddistkr1-a.akamaihd.net`. Это direct, гигабит мимо туннеля.

`proxy_string` — VLESS WS из `/root/creds/cudy-wr3000p-vless.url`, не ссылка TR3000.

```bash
uci commit podkop
/etc/init.d/podkop restart
# если в логе «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

Проверка с роутера:

```bash
nslookup battle.net 127.0.0.1          # 198.18.x.x
nslookup www.blizzard.com 127.0.0.1    # 198.18.x.x
nslookup level3.blizzard.com 127.0.0.1 # публичный Akamai, не 198.18
nslookup blzddist1-a.akamaihd.net 127.0.0.1
```

Задержка узла (Clash API podkop, как на эталоне): `main-out` порядка 100–200 мс, не timeout. С роутера `wget -S -O /dev/null https://vpn2.sharpmaind.ru/` → HTTP 200. BusyBox `nc` без `-w` не использовать как проверку.

## 7. Tailscale

На роутере:

```bash
tailscale up --auth-key="$TS_AUTHKEY" --hostname=cudy-wr3000p --ssh --advertise-routes=192.168.2.0/24 --accept-dns=false
```

Ключ тот же многоразовый, что для агента (если не истёк; ориентир до ~2027-01-02). Не писать ключ в отчёт.

Дальше как на TR3000:

- SSH сервера Tailscale включён
- MagicDNS выключен
- `--accept-routes` на роутере не включать, Funnel не включать
- firewall: зона `tailscale`, forwarding lan↔tailscale и tailscale→wan, как в `uci show firewall` эталона
- в панели Tailscale маршрут `192.168.2.0/24` этого узла **не аппрувить**, пока в сети ещё TR3000 с тем же маршрутом. После cutover аппрув только у `cudy-wr3000p`, у старого `cudy` маршрут снять

Агент с ноутбука: `tailscale ssh root@<новый 100.x>`, `--accept-routes=false`.

## 8. Firewall и WOL

Повторить с эталона:

- WAN input REJECT, исключения только DHCP renew / ping / IGMP, если они есть на TR3000
- LAN accept, masquerade на wan
- Dropbear слушает LAN; с wan 22 закрыт
- LuCI `uhttpd` на 80/443 допустим при wan REJECT

WOL:

```bash
opkg install etherwake luci-app-wol
uci commit
/etc/init.d/uhttpd restart
```

Будить только устройства в LAN `192.168.2.0/24`. Интерфейс для etherwake — br-lan. MAC целевого ПК пользователь даст отдельно; в конфиг заранее чужие MAC не выдумывать. Проверка пакета: `etherwake -i br-lan <mac>` когда ПК выключен и кабель в этом роутере.

## 9. Приёмка

| Проверка | Ожидание |
|---|---|
| `board_name` | `cudy,wr3000p-v1` |
| OpenWrt | 25.12.5 mediatek/filogic |
| overlay | не 100%, есть запас |
| LAN | 192.168.2.1, TR3000 выключен |
| IPv6 | нет wan6, нет RA |
| `vpn2` | резолвится в 185.141.217.43 либо в FakeIP, если домен в списке podkop |
| battle.net | 198.18.x.x |
| level3.blizzard.com | публичный адрес |
| VLESS | свой пользователь `cudy_wr3000p`, Default-Squad, delay main-out живой |
| Tailscale | hostname `cudy-wr3000p`, SSH по 100.x, Funnel выкл |
| WOL | пакеты etherwake/LuCI есть |
| `sing-box` UCI | enabled=0, процесс при этом запущен podkop |

В отчёт пользователю: SN, свободно на overlay, Tailscale IP нового роутера, что подписка `cudy_wr3000p` создана, какие домены podkop отличаются от эталона (должно быть «нет»), результат nslookup battle.net и level3. Без ключей и без VLESS URI.
