# TR3000 — лог Wi‑Fi iPhone Air

**Клиент:** iPhone Air, MAC `a6:c5:ff:0d:e9:60`, DHCP `192.168.2.104`.

**Файл на роутере:** `/root/log/iphone-air-wifi.log` (ротация ~128 KB).

**Сервис:** `/etc/init.d/log-iphone-air` (autostart) — каждые 30 с снимок `iw station dump`, плюс `logread -f` по MAC (assoc/disassoc в hostapd).

**Скрипты в репо:** `ops/scripts/tr3000-log-iphone-air.sh`, `ops/scripts/tr3000-log-iphone-air.init`.

**Деплой:**

```bash
tailscale ssh root@100.81.160.52 "cat > /usr/bin/log-iphone-air.sh" < ops/scripts/tr3000-log-iphone-air.sh
tailscale ssh root@100.81.160.52 "cat > /etc/init.d/log-iphone-air" < ops/scripts/tr3000-log-iphone-air.init
tailscale ssh root@100.81.160.52 '/etc/init.d/log-iphone-air enable; /etc/init.d/log-iphone-air restart'
```

**Наблюдение 2026-10-28:** на 5 GHz у станции очень высокий `tx failed` при нормальном RSSI — типичная причина «отвалов»; включено `disassoc_low_ack=0` на обоих SSID.

**Смотреть:**

```bash
tailscale ssh root@100.81.160.52 'tail -f /root/log/iphone-air-wifi.log'
grep STATE=offline /root/log/iphone-air-wifi.log
```
