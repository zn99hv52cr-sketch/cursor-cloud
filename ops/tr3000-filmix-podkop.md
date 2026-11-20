# TR3000 — Filmix на Mi TV (буфер)

**Роутер:** Cudy TR3000. Видео CDN `nl221.werkecdn.me` (`66.90.102.57`) с МГТС: ping есть, **HTTPS 443 таймаут**. С WR3000P тот же CDN отвечает за 0.2 с.

KotiKey VLESS с TR тоже не открывает 443 на этот IP (все 9 нод).

## Фикс

WR слушает `100.104.207.62:10443` (`socat` → `66.90.102.57:443`).  
TR DNAT: LAN `66.90.102.57:443` → WR:10443 (Tailscale). TLS до CDN сквозной.

Проверка с TR:  
`curl -k --connect-to nl221.werkecdn.me:443:100.104.207.62:10443 https://nl221.werkecdn.me/` → 403 (корень), не таймаут.

На TV: полностью закрыть Filmix и снова Play.
