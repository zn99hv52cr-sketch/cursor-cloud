# TR3000 — HDrezka MiTV: постеры серые, видео ок

## Причина

Плеер и **voidboost** идут через **exclusion `hdrezka_direct` → direct** (это трогать нельзя).

Постеры MiTV/Lumen часто с других хостов (**`static.hdrezka.ac`**, **`i.postimg.cc`**, зеркала), которых нет в `hdrezka_direct`. Тогда трафик попадает в **main-out (VPN/FakeIP)** → TCP/DNS для картинок рвётся, на ТВ серые плитки. Метаданные (названия) приходят по API.

## Фикс (только постеры, видео не меняем)

На TR3000 (`ssh root@192.168.2.1`):

```sh
for d in \
  i.postimg.cc postimg.cc postimg.top \
  static.hdrezka.ac statichdrezka.ac st.hdrezka.ac \
  hdrezka-home.tv hdrzk.org image.tmdb.org; do
  uci add_list podkop.hdrezka_direct.user_domains="$d" 2>/dev/null || true
done
uci commit podkop
/etc/init.d/podkop restart
sleep 5
killall -HUP dnsmasq 2>/dev/null
rm -f /tmp/sing-box/cache.db
```

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