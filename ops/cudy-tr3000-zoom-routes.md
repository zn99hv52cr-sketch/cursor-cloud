# Cudy TR3000 — маршруты Zoom

Только **TR3000** (`100.81.160.52`). WR3000P не трогаем.

Добавляет домены Zoom в `podkop.main.user_domains` (трафик через VPN/sing-box).

```bash
OPENWRT_PASSWORD='…' ops/scripts/cudy-tr3000-add-zoom-domains.sh
# или после Tailscale SSH check:
ops/scripts/cudy-tr3000-add-zoom-domains.sh
```

Домены: `zoom.us`, `zoom.com`, `zoomgov.com`, `zoomcdn.com`, `zoomcrc.com`.

Проверка: `nslookup zoom.us 127.0.0.1` → FakeIP `198.18/198.20`.
