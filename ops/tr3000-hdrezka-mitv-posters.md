# TR3000 — HDrezka MiTV: постеры серые, видео ок

## Причина

Плеер и **voidboost** идут через **exclusion `hdrezka_direct` → direct** (это трогать нельзя).

Поиск/каталог тянет **`st.hdrezka.ac`**, **`static.hdrezka.ac`**, postimg. С **WAN direct** к `179.43.x` часто **таймаут** (DPI), а **voidboost** на direct живёт. Если эти хосты в `hdrezka_direct` → серые плитки после поиска при рабочем видео. MiTV может идти на CDN **по IP** (DoH) — нужны `user_subnets` на `179.43/16`, `82.221/16`.

## Фикс (постеры через VPN, voidboost — direct)

Скрипт: `ops/scripts/tr3000-hdrezka-search-posters.sh` (или с TR: `ssh tr3000 'sh -s' < …`).

Кратко: убрать poster-домены из `hdrezka_direct`, добавить в `podkop.main.user_domains` + подсети CDN в `podkop.main.user_subnets`, `podkop restart`.

Проверка с роутера:

```sh
nslookup static.hdrezka.ac 127.0.0.42
nslookup i.postimg.cc 127.0.0.42
# должны быть обычные A, не 198.18.x (fakeip) — для direct exclusion DNS может быть real
```

На ТВ: принудительно остановить приложение → снова открыть каталог.

## После ребута

Подробно: [tr3000-podkop-boot.md](./tr3000-podkop-boot.md) (status `not running`, wan-recover reload, mangle).

### Постеры снова серые

На TR кастомный **`podkop-tun-up`** в конце старта делает `nft flush` для `mangle`/`proxy`, а **`create_nft_rules` в podkop** отрабатывает **до** tun-up — в итоге цепочка mangle пустая, трафик MiTV к `179.43/16` и `198.18.0.0/15` уходит в **WAN direct**.

Проверка:

```sh
nft list chain inet PodkopTable mangle | grep counter   # пусто = баг
ip route get 179.43.158.226 from 192.168.2.145 iif br-lan   # eth0 = плохо, sbtun = ок
```

Фикс: скопировать `ops/scripts/tr3000-podkop-restore-mangle.sh` → `/usr/bin/podkop-restore-mangle.sh`, в конец **`/usr/bin/podkop-tun-up`** добавить строку:

```sh
/usr/bin/podkop-restore-mangle.sh
```

После ребута или `podkop restart` — один раз вручную, если забыли hook:

```sh
/usr/bin/podkop-restore-mangle.sh
```

## Чего не делать

- Не убирать **voidboost** / **stream.*** из `hdrezka_direct`.
- Не менять **main-out** / KotiKey для HDrezka.
- Не отключать section `hdrezka_direct` (connection_type `exclusion`).