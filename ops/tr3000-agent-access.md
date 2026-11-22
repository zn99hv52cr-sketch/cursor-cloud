# TR3000: постоянный доступ Cloud Agent (Tailscale)

Роутер: **cudy-tr3000**, Tailscale `100.81.160.52`, LAN `192.168.2.1`. MagicDNS на роутере **не включать**.

## Что уже работает (без твоего клика)

Агент заходит по **dropbear на порту 2222**, ключ `wr3000p_ed25519` (тот же, что на WR3000P):

```bash
ssh -p 2222 -i ~/.ssh/wr3000p_ed25519 root@100.81.160.52
```

Порт **22** на этом IP перехватывает **Tailscale SSH** — без браузера облако туда не попадёт.

Публичный ключ агента (уже должен быть в `/etc/dropbear/authorized_keys` на TR):

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag
```

Проверка с агента: `ssh tr3000 'echo OK'` при `~/.ssh/config` → `Port 2222`.

---

## Вариант A — разовый пуск через Tailscale SSH (порт 22)

Когда агент пишет:

```text
# Tailscale SSH requires an additional check.
# To authenticate, visit: https://login.tailscale.com/a/...
```

1. Открой ссылку **под аккаунтом sharpmaind** (не «Machines → …» в админке).
2. Подтверди доступ для узла агента (**cursor-cloud**, `100.66.76.102`).
3. В тот же запуск агента команда повторится и пройдёт.

Актуальная ссылка (22 ноя 2026):  
https://login.tailscale.com/a/lbc2a33f2ae846  

(При новой сессии URL может смениться — смотри вывод `tailscale ssh` / `ssh root@100.81.160.52` в логе агента.)

После клика доступен:

```bash
tailscale ssh root@100.81.160.52
```

Это **не заменяет** 2222: на TR снова `RunSSH: true` после ребута, и снова понадобится `/a/...` для новой машины/сессии.

---

## Вариант B — политика SSH в Tailscale Admin (стабильнее для :22)

[Admin Console → SSH](https://login.tailscale.com/admin/acls) (или Access controls → SSH):

Пример правила:

| From | To | Action |
|------|-----|--------|
| `autogroup:member` | tag или имя `cudy-tr3000` | SSH as root |

Или явно разрешить исходящий SSH с тега/узла `cursor-cloud` на `100.81.160.52`.

Сохранить ACL, при первом входе с нового агента — один раз `/a/...` как выше.

---

## Вариант C — постоянно без Tailscale SSH (рекомендуется для агента)

Один раз с дома (LAN `ssh root@192.168.2.1` или LuCI → Terminal):

```sh
# 1) Ключ агента в authorized_keys
grep -q 'cursor-wr3000p-diag' /etc/dropbear/authorized_keys 2>/dev/null || \
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdYxd9EAfEsQipBfEwneZqUjd3RL3LZQat39Hj8K2gb cursor-wr3000p-diag' >> /etc/dropbear/authorized_keys

# 2) Второй dropbear — порт 2222 (облако всегда сюда)
uci -q get dropbear.alt.Port || {
  uci set dropbear.alt=dropbear
  uci set dropbear.alt.enable='1'
  uci set dropbear.alt.Port='2222'
  uci set dropbear.alt.PasswordAuth='on'
  uci set dropbear.alt.RootPasswordAuth='on'
  uci commit dropbear
  /etc/init.d/dropbear restart
}

# 3) Отключить перехват SSH на 22
tailscale set --ssh=false --accept-risk=lose-ssh

# 4) После ребута снова выключить RunSSH
cat > /etc/init.d/tailscale-no-ssh << 'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() { sleep 25; tailscale set --ssh=false --accept-risk=lose-ssh 2>/dev/null; }
start() { boot; }
EOF
chmod +x /etc/init.d/tailscale-no-ssh
/etc/init.d/tailscale-no-ssh enable
```

Готовый скрипт (LuCI/LAN): `ops/scripts/tr3000-enable-remote-access.sh` — LuCI/HTTP; для полного набора выше дополни пункты 2–4.

Агент в Cloud Environment должны держать:

- `TS_AUTHKEY` — многоразовый ключ Tailscale (обновлять до ~янв 2027).
- При старте сессии: `tailscale up --auth-key="$TS_AUTHKEY" --hostname=cursor-cloud --accept-routes=false`
- **Не** использовать `--accept-routes=true` (не тянуть `192.168.2.0/24` на агента).

---

## Сводка

| Способ | Нужен ты | Постоянство |
|--------|----------|-------------|
| `ssh -p 2222` + ключ | Нет (если ключ и 2222 на месте) | Да |
| Клик `/a/...` | Да, раз на связку агент↔аккаунт | Повтор при новой VM/ссылке |
| ACL SSH в админке | Настройка один раз | Да, с редким `/a/` |
| `tailscale set --ssh=false` + 2222 | Один раз с LAN | Да |