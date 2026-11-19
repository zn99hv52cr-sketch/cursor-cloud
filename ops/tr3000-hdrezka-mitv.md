# WR3000P — HDRezka на Mi TV Box

## Симптом

Приложение HDRezka на Mi TV: долго буферизует видео, превью/API ок.

## Причина (2026-11-19)

Podkop гонял **домены** rezka/voidboost через sing-box (fakeip), а **потоки** — на IP CDN **82.221.x** и **179.43.x**. TV часто резолвит DNS сам (Google/DoH) и ходит **на IP** → трафик **мимо** fakeip, **не в прокси** → `user_subnets` этих CDN не содержали.

## Фикс на TR3000

В `podkop.main.user_subnets` добавлены:

- `179.43.189.163/32`, `179.43.163.206/32` — hdrezka.ag / static
- `82.221.105.13/32`, `82.221.128.101/32`, `82.221.0.0/16` — hdrzk.org / voidboost CDN
- `185.231.220.9/32` — statichdrezka.ac
- `176.58.49.243/32` — voidcrystal.org

```sh
uci commit podkop && /etc/init.d/podkop restart
```

Проверка: `nft list set inet PodkopTable podkop_subnets | grep 82.221`

Домены `hdrzk.org`, `voidboost.*`, `hdrezka.*` уже в `user_domains` — не трогать.