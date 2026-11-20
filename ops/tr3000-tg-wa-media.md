# TR3000 — фото WhatsApp без VPN

iTruba (`192.168.2.156`) качает фото с `media-hel3-1.cdn.whatsapp.net` (FakeIP `198.18.5.158`).
TCP на этот хост живой (HTTP 404 на корень, ~0.4 с). **QUIC (UDP 443) через sbtun — 0 ответов**, приложение висит.

На TR:

- `iifname br-lan udp dport 443 reject` — весь QUIC с LAN, не только в WAN
- TCPMSS 1240 на sbtun
- DoH 8.8.8.8/1.1.1.1:443 в WAN reject

Проверка: hel3 404, `web.telegram.org` 200, YouTube 204.

Убить WhatsApp из карточек и открыть заново. Если на телефоне ещё висит Happ (у iPhone сессии на `147.125.132.43`) — выключить.
