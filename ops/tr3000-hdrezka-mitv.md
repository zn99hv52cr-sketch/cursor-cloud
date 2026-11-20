# TR3000 — HDRezka на Mi TV Box

**Роутер:** Cudy TR3000 (`root@100.81.160.52`). WR3000P не трогаем.

## Симптом

Поиск находит фильмы (названия есть), **постеры пустые**, видео не стартует.

## Что реально дергает Mi TV (dnsmasq, `192.168.2.145`)

| Запрос | Зачем | Куда |
| --- | --- | --- |
| `hdrzk.org` | API / поиск | **direct** (exclusion) |
| `st.hdrezka.ac` | постеры | **туннель** (`179.43.158.226`) |
| `hdrezka-fly.net` | плеер / стрим | **туннель** (`179.43.154.139`) |
| `voidcrystal.org` / `voidboost.*` | CDN видео | **туннель** |

## Почему ломалось

1. **Russia inside** тащит весь блок HDRezka в VPN. API с FI даёт 403 → каталог пустой. Лечится секцией `exclusion` для **`hdrzk.org`** (не для `hdrezka.ac`!).
2. **`hdrezka.ac` в exclusion = domain_suffix** → `st.hdrezka.ac` тоже уходил **напрямую**. МГТС режет `179.43.x` (таймаут) → серые плитки без картинок.
3. Плеер ходит на **`hdrezka-fly.net`**, его не было в `user_domains` → реальный IP мимо туннеля.

## Фикс на TR3000

**Exclusion `hdrezka_direct` (только API, без `hdrezka.ac` / `.ag`):**  
`hdrzk.org`, `hdrezka.me`, `hdrezka.tv`, `hdrezka.tech`, `hdrezka.app`, `hd-rezka.tv`, `rezka.*`, `rezkify.com`.

**`main.user_domains` (туннель):**  
`st.hdrezka.ac`, `static.hdrezka.ac`, `statichdrezka.ac`, `hdrezka-fly.net`, `voidboost.*`, `voidcrystal.org`, `stream.voidboost.*`, `voidslam.org`.

**`main.user_subnets`:**  
`179.43.158.226/32`, `179.43.154.139/32`, `82.221.128.101/32`, `176.58.49.243/32`, `89.105.207.117/32`, `176.58.48.71/32`, `176.58.48.69/32`.  
Не класть `82.221.0.0/16` и `82.221.105.13` (это API).

Проверка с роутера (после прогрева podkop ~5 с):

```sh
nslookup st.hdrezka.ac 127.0.0.1     # fakeip 198.18.x
curl -k -m 12 -o /dev/null -w '%{http_code}\n' https://st.hdrezka.ac/i/0.png   # 200
curl -k -m 12 -o /dev/null -w '%{http_code}\n' https://hdrezka-fly.net/        # 200
```

На TV: полностью закрыть HDRezka и открыть поиск снова.

```sh
sh ops/scripts/tr3000-hdrezka-direct-api.sh
```
