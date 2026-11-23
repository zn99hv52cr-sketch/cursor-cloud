# WR3000P — watchdog Telegram / podkop

## Проблема

Раз в ~1 ч зависает egress sing-box к DC Telegram (`149.154.167.x`, лог `no route to host`). YouTube часто жив, `web.telegram.org` — таймаут.

Лечит ` /etc/init.d/podkop restart`.

## Cron на роутере (2026-11-20)

В `/etc/crontabs/root`:

```
*/20 * * * * curl -4 -m 10 -sS -o /dev/null https://web.telegram.org/ || /etc/init.d/podkop restart
```

`crontab -l` / `cron reload` при смене.