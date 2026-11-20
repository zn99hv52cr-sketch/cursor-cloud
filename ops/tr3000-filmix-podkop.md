# TR3000 — Filmix (Mi TV / Android)

**Роутер:** Cudy TR3000 (`root@100.81.160.52`). WR не трогаем.

## Симптом

Каталог открывается, при старте видео — бесконечная **буферизация**.

## Причина

Потоки идут с CDN вроде **`*.cdnsqu.com`**, **`srv224.com`**, иногда **`nl210.cdnlast.com` → cdnsqu** (HLS).  
В podkop не было **`cdnsqu.com`** и IP **`65.21.224.187`**, **`50.7.240.188`**, **`67.159.8.102`**.  
TV часто резолвит DNS сам → трафик на **реальные IP CDN** не попадал в nft/tun → плеер висел.

API (`filmixapp.cyou`, `fxapp.biz`) в туннеле остаётся — для них proxy нужен у части провайдеров.

## Фикс (2026-11-20)

**`podkop.main.user_domains`** (добавить к уже существующим filmix.*):

- `cdnsqu.com` — видео/HLS
- `filmix.lat` — зеркало API
- `thumbs.filmixapp.cyou` — постеры
- `filmix.quest` — зеркало (опционально)

Уже должны быть: `filmixapp.cyou`, `fxapp.biz`, `cdnlast.com`, `srv224.com`, `franecki.net`, `getter.cfd`, …

**`podkop.main.user_subnets`:**

- `50.7.240.188/32` — `nl210.cdnsqu.com`
- `65.21.160.158/32`, `65.21.224.187/32` — `srv224.com` (IP может смениться)
- `67.159.8.102/32` — `thumbs.filmixapp.cyou`
- `185.80.234.0/24` — API Filmix

```sh
uci commit podkop && /etc/init.d/podkop restart
```

Проверка на роутере:

- `nslookup nl210.cdnsqu.com 127.0.0.1` → fakeip `198.18.x`
- `nslookup srv224.com 127.0.0.1` → fakeip

На Mi TV: выгрузить Filmix из памяти и снова открыть ролик.

## Если снова буферит

В настройках приложения (платный аккаунт): **Плеер → выбор сервера** — другой CDN-узел.  
Сообщить домен из лога/URL плеера — добавим в `user_domains` / `user_subnets`.