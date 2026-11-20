# TR3000 — HDRezka напрямую (как на роутере провайдера)

**Роутер:** Cudy TR3000. WR не трогаем.

На МГТС без VPN HDRezka грузится. Через podkop/VLESS — нет (403 / пустые постеры / плеер).

## Как сделано

1. Секция podkop `hdrezka_direct` (`exclusion`) — russia_inside не уводит rezka в туннель.
2. Домены **сняты** с `main.user_domains` / `user_subnets` (нет маршрута в `sbtun`).
3. `/etc/dnsmasq.d/hdrezka-direct.conf` — DNS на `77.88.8.8`, **не FakeIP**. Приставка видит те же IP, что на роутере провайдера.

YouTube/Telegram по-прежнему FakeIP → VLESS.

На TV: полностью закрыть HDRezka и открыть снова.

```sh
sh ops/scripts/tr3000-hdrezka-isp-direct.sh
```
