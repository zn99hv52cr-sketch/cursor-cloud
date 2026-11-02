# FI VPS — AmneziaWG 3.1

Сервер: `185.141.217.43` (`awg.sharpmaind.ru`).

## Что сделано

- Контейнер **`amnezia-awg3`** (бывший `amnezia-awg2`), порт UDP **51820**
- Протокол **AWG 3.1**: `HeaderProtectionKey`, `ContentPaddingAddition`, тайминги, `RandomTrailers=on`, `H1..H4=1..4`, `S1..S4≥12`
- Ключи сервера и пиры сохранены; старые клиентские `.conf` **не совместимы** — нужны новые
- Панель: `prvtpro/amnezia-panel:1.6.7`, протокол в UI — **AmneziaWG 3.1**
- Бэкап: `/root/backups/awg31-upgrade-*`

## Клиенты

1. AmneziaVPN / AmneziaWG **с поддержкой 3.1** (не старый 2.0-only)
2. Скачать новый конфиг из панели или выданный `*-awg31.conf`
3. Старые профили удалить — handshake с ними не пройдёт

## Откат

Из бэкапа восстановить `awg-data/awg0.conf` (2.0), переименовать контейнер обратно при необходимости, панель можно вернуть на `1.5.0` + `data.json` из того же бэкапа.
