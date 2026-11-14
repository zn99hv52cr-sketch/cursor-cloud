# WR3000P VPN (Rostelecom)

Router: Cudy WR3000P OpenWrt — Tailscale `100.104.207.62` (`cudy-wr3000p`).  
ISP: Rostelecom (not the same path as TR3000). Lightly compare TR3000 ideas only; keep this router’s own dualfix/TUN layout.

## Working design

| Piece | Value |
| --- | --- |
| Inbound | sing-box **TUN** `sbtun` (tag `tproxy-in`), MTU 1400, `auto_route=false` |
| FakeIP | `198.20.0.0/15` (also route `198.18.0.0/15` if old cache leaks) |
| Outbounds | VLESS WS `path=/vpn` Host `vpn2.sharpmaind.ru` |
| Nodes | `main-1` = `89.125.57.161:443`, `main-2` = `185.141.217.43:443` |
| Default | **`main-2-out` (185)** — more stable from Rostelecom |
| QUIC | blocked on TUN inbound; `podkop.settings.disable_quic=1` |
| TV `.164` | DNS DNAT → router `192.168.1.1` (FakeIP); block DoH/QUIC/IPv6 |

Static `ip route … dev sbtun` covers FakeIP plus Google / Meta / Telegram ranges so apps that bypass FakeIP still hit the tunnel.

## Boot / watch

- `/usr/bin/podkop-tun-up` — ensure TUN inbound, WS transport, routes, fw4 forward/MSS; **must** restore empty `config.json` from `.ok` / overlay backup (never `exit 1` on empty)
- `/etc/init.d/podkop-tun` — run up at boot + every ~45s
- `/usr/bin/podkop-guard` + init — if `sing-box` dead **or** `config.json` empty/invalid **or** `sbtun`/FakeIP route missing → `podkop start` + tun-up
- `/usr/bin/podkop-path-watch` + init — if path probe fails, Clash API select `main-2-out`
- Config rewrites (`tun-up`, `firewall.user` QUIC strip) use `flock` on `/var/lock/sing-box-config.lock` and never `mv` an empty/invalid JSON onto `/etc/sing-box/config.json`

Backups on device: `/overlay/backups/wr3000p-*`, note `WR3000P-FIX-20261112.txt`. Historical known-good pattern: `bak-dualfix-20261027`. Good config copy: `/etc/sing-box/config.json.ok` + `/overlay/backups/sing-box-config.ok.json`.

### Incident 2026-11-14 — why “guard didn’t help”

**Symptom:** hours of “nothing opens”; Telegram sometimes OK, YouTube/DNS FakeIP dead.

**Root cause:** around **07:50 Europe/Moscow** `/etc/sing-box/config.json` became **empty** (`FATAL unexpected end of JSON input`). Likely race: cron `firewall.user` (every 5m, `jq` → `mv` + `sing-box restart`) vs `podkop-tun-up` (also `jq` → `mv` + stop/start). Empty MD5 `d41d8cd98f…` still present at recovery.

**Why old guard failed:** the installed guard only called `podkop-tun-up` when `sbtun` was missing — it did **not** restart `sing-box`/`podkop` on dead process / empty config. Worse: old `podkop-tun-up` started with `[ -s config.json ] || exit 1`, so once the file was empty it **exited immediately** every ~20s and never repaired anything.

**Fix applied on router:** flocked atomic writes, restore from `.ok`, guard checks empty/invalid JSON and restarts podkop, `sing-box` uci `enabled=1`.

## Do not

- Do not replace this with a full TR3000 config copy.
- Do not leave FakeIP on while disabling TUN/`podkop-tun-up` (LAN blackhole).
- Do not use Reality / xhttp packet-up on this OpenWrt path (HAProxy/WS `/vpn` only).
- Do not enable `tcp_fast_open` on VLESS here.

## Quick verify (on router)

```sh
ip -br link show sbtun
ip route get 198.20.0.1
nslookup youtube.com 192.168.1.1
curl -4 -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 10 https://www.youtube.com/
curl -4 -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 10 https://web.telegram.org/k/
curl -4 -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 10 https://www.instagram.com/
```

Clash API secret is in `experimental.clash_api.secret` on the device; `main-out` should show `now=main-2-out` unless manually changed.


## YouTube RU egress (no EE ads)

Inbound may be `89.125.57.161` / `185.141.217.43`. Tunnel **exit** must be VPS src `193.124.224.248` (`ops/vps-youtube-ee-ads.md`). If YouTube shows EE ads, re-run `egress-src-248.sh` on the FI box — do **not** set default src to `.161`.

## TV (Xiaomi `.164`)

DNS must hit the router (FakeIP + `filter_aaaa`), not `1.1.1.1` (AAAA blackhole). Policy: `/usr/bin/tv-yt-policy` via firewall include. QUIC/DoH blocked; LAN IPv6 forward rejected.

### Note 2026-11-12 evening
Confirmed working: TV YouTube with DNS forced to `192.168.1.1` (FakeIP). `wr-helper tv-policy` no longer installs `1.1.1.1` DNAT (that path returned AAAA and broke the box).
