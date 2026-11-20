# WR3000P — Filmix (Mi TV / Android)

## Симптом

Приложение Filmix не грузится (нет API/каталога).

## Причина

В podkop не было доменов Filmix. API приложения: **`filmixapp.cyou`** (и запасной **`fxapp.biz`**), плюс **`filmix.my`**, постеры **`thumbs.filmix.my`**, CDN/плеер: **`cdnlast.com`**, **`srv224.com`**, **`franecki.net`**, **`getter.cfd`**.

С DNS TV часто ходит на IP **185.80.234.x** — добавлены подсети.

## Фикс (2026-11-20, TR3000)

`podkop.main.user_domains`: filmix.my, filmix.tv, filmix.co, filmix.ac, filmix.biz, filmix.me, filmix.zone, filmix.fan, filmix.app, **filmixapp.cyou**, thumbs.filmix.my, cdn.filmix.my, **fxapp.biz**, cdnlast.com, srv224.com, franecki.net, getter.cfd.

`podkop.main.user_subnets`: `185.80.234.0/24`, точечные IP CDN (83.217.214.237, 213.142.147.64, 45.88.104.90, …).

```sh
uci commit podkop && /etc/init.d/podkop restart
```

На роутере `curl -k https://filmixapp.cyou/` должен отвечать быстро (не таймаут 10+ с).

На ТВ: выгрузить Filmix из памяти и открыть снова.