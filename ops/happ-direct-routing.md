# Happ: прямые домены для всех

2026-10-08. Профиль маршрутизации `SharpVpn` лежит в заголовке подписки `routing: happ://routing/onadd/...` и приходит каждому пользователю Happ. Раньше напрямую шли только Apple/iCloud, адреса панели и локальные сети.

`GlobalProxy` остаётся `true`. YouTube, Telegram и остальные зарубежные сайты по-прежнему идут через VPN. Напрямую уходят только правила ниже.

## Что добавлено

Список с телефона, плюс VK, Element, Ozon Банк, Сбер и Wildberries.

- Магазины и работа: AliExpress, Avito, Dixy (`dixy.com`, `dixy.ru`, `api.dixy.ru`), Magnit, `gaskar.group`, `m.gaskar.group`, `evr.local`, `helpdesk.evr.local`.
- VK: `geosite:vk`, плюс `vk.com`, `vk.ru`, `vk.me`, `userapi.com`, `vkuseraudio.net`, `vk-cdn.net`.
- Element: `element.io`, `app.element.io`, `matrix.org`, `vector.im`, `element.gaskar.group`.
- Ozon и Ozon Банк: `geosite:ozon`, `finance.ozon.ru`, `bank.ozon.ru`.
- Сбер: `geosite:sber`, `sber.ru`, `sberbank.ru`, `sberbank.com`, `sbrf.ru`. В геосписке Сбера также 2ГИС, Okko и Мегамаркет.
- Wildberries: `geosite:wildberries`, `wildberries.ru`, `wb.ru`, `wb-bank.ru`, `wbbasket.ru`, `wbstatic.net`, `wbcontent.net`.
- Все зоны `.ru` и `.su`: `geosite:category-ru`, `geosite:category-bank-ru`, `regexp:.*\.ru$`, `regexp:.*\.su$`.
- Сети: `10.120.10.0/24`, `10.120.100.0/24`, `10.120.10.39/32`, `10.120.10.45/32`, `192.168.44.0/24`, `192.168.44.101/32`. Общие частные сети и `185.141.217.43/32` не трогались.

Адрес `192.168.44.101` записан как IP, не как `domain:`.

## Как применяется

Happ забирает профиль при обновлении подписки (интервал 1 час) и перезаписывает локальный профиль с именем `SharpVpn`. Ручные правки этого профиля на телефоне после обновления заменяются серверным списком.

v2raytun и v2rayNG этот заголовок не читают. У них остаётся тот маршрут, который задан в самом приложении.

Бэкап настроек подписки до правки: `/root/backups/subscription-settings-20261008T162704Z.json`.
