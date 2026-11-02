# Sveta, Дом.ru — Megafon Reality (только сквад Sveta-DomRu)

Дом.ru DPI рвёт долгий WS на `vpn2` (`.43:443`). xHTTP у неё в логах не поднимался — только `vless-main`.

## Рабочий путь

1. **Megafon- Reality** / **Reality Chrome** — `193.124.224.248:443`, VLESS+Reality, SNI `www.microsoft.com`  
   (на сервере: xray `:9443` + DNAT `.248:443→9443`; Caddy только на `185.141.217.43`)
2. Megafon packet-up / stream-up / packet-up iOS / stream — запас по `vpn2`
3. Reality 2083 / 2096 — запас
4. Megafon WS — цепляется, но DPI рвёт

Все эти хосты: `ALLOW_ONLY` → `Sveta-DomRu` (`b52de567-…`). Чужим не светятся.

## Инфра (прозрачно для остальных)

- Caddy `bind 185.141.217.43` (DNS `vpn2` → `.43`)
- systemd `sveta-reality-248-nat.service` → `/opt/remnawave/sveta-reality-248.nat.sh`
- inbound `vless-reality-248` в профиле + activeInbounds ноды + сквад Светы

## iPhone

Птянуть подписку в Happ → должен взять **Megafon- Reality**. Не сидеть на WS.
