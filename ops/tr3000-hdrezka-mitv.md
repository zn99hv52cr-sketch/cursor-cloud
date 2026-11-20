# TR3000 — HDRezka на Mi TV Box

**Роутер:** Cudy TR3000 (`root@100.81.160.52`). WR3000P не трогаем.

## Симптом

Приложение HDRezka на Mi TV: каталог пустой или «почти ничего не грузит», буферизация.

## Причина

1. Список Podkop **Russia inside** включает блок **HDRezka** → DNS fakeip и трафик каталога/API шёл в **FI VPN** → **HTTP 403** с датацентрового IP.
2. Через VPN недоступны зеркала вроде `hdrzk.org` (API на `82.221.105.13`); с домашнего МГТС ответ нормальный (пусть и с редиректами/403 на отдельных зеркалах).
3. **Видео** идёт с CDN **voidboost** — его по-прежнему нужно гнать через podkop + `user_subnets` на IP CDN.

## Фикс на TR3000

1. Секция **`hdrezka_direct`** с `connection_type=exclusion` и доменами каталога (см. скрипт).
2. В **`main.user_domains`** только `voidboost.*` и `voidcrystal.org` (не дублировать hdrezka).
3. В **`main.user_subnets`**: `82.221.128.101/32`, `176.58.49.243/32` — **без** `82.221.0.0/16` и без `179.43.x` (чтобы API-IP не утащить в туннель).

```sh
# с хоста с ключом или на самом Cudy:
sh ops/scripts/tr3000-hdrezka-direct-api.sh
```

Проверка на роутере:

- `nslookup hdrezka.me 127.0.0.1` — может остаться fakeip `198.18.x` (так задумано в podkop), но маршрут **direct-out** важнее:
  `podkop show_sing_box_config | jq '.route.rules[] | select(.outbound=="direct-out")'`
- `nslookup voidboost.net 127.0.0.1` → fakeip (туннель).
- На TV: полный выход из приложения и повторный запуск.

## Примечание про MGTS

`hdrezka.me` с провайдера может редиректить на `blocked.mgts.ru` — приложение обычно использует зеркала (`hdrzk.org` и т.д.), для них exclusion + прямой выход критичен.