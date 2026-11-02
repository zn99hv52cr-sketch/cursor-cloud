# Cudy TR3000 + WR3000P — маршруты ChatGPT

Добавляет домены OpenAI/ChatGPT в `podkop.main.user_domains` (трафик через VPN/sing-box).

```bash
# предпочтительно (без Tailscale SSH check):
OPENWRT_PASSWORD='…' ops/scripts/cudy-add-chatgpt-domains.sh

# или после approve Tailscale SSH check:
ops/scripts/cudy-add-chatgpt-domains.sh
```

Роутеры по Tailscale IP: `100.81.160.52` (TR3000), `100.104.207.62` (WR3000P). MagicDNS на роутерах не включать.

Домены: `chatgpt.com`, `openai.com`, `chat/api/auth/platform.openai.com`, `oaistatic.com`, `oaiusercontent.com`, `ab/ws.chatgpt.com`, `sora.com`, `sora.chatgpt.com`, `images/cdn.openai.com`.

Проверка: `nslookup chatgpt.com 127.0.0.1` → FakeIP `198.18/198.20` = через туннель.
