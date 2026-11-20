# TR3000 — фото TG/WA без VPN на телефоне

Чат шёл, картинки нет: QUIC/DoH уходили в МГТС мимо туннеля, плюс на `sbtun` не было clamp MSS (mtu 1400).

На TR:

- UDP 443 LAN→WAN reject (QUIC не утекает)
- DoH на 1.1.1.1 / 8.8.8.8 / 9.9.9.9:443 reject
- TCPMSS 1240 на `sbtun`
- DC Telegram `149.154.160.0/20` и WA `57.144.0.0/14` уже в sbtun

Проверка: `web.telegram.org` 200, `youtube generate_204` 204, `mmg.whatsapp.net` 404 (корень).

На телефоне полностью выключить Happ/VPN, убить TG и WA из карточек, открыть заново.
