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

## Чего не делать

- Не убирать **voidboost** / **stream.*** из `hdrezka_direct`.
- Не менять **main-out** / KotiKey для HDrezka.
- Не отключать section `hdrezka_direct` (connection_type `exclusion`).