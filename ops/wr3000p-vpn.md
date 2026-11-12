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
| TV `.164` | DNS DNAT → `1.1.1.1`; block DoH/QUIC |

Static `ip route … dev sbtun` covers FakeIP plus Google / Meta / Telegram ranges so apps that bypass FakeIP still hit the tunnel.

## Boot / watch

- `/usr/bin/podkop-tun-up` — ensure TUN inbound, WS transport, routes, fw4 forward/MSS
- `/etc/init.d/podkop-tun` — run up at boot + every ~45s
- `/usr/bin/podkop-guard` + init — if `sbtun`/FakeIP route missing, re-run up
- `/usr/bin/podkop-path-watch` + init — if path probe fails, Clash API select `main-2-out`

Backups on device: `/overlay/backups/wr3000p-*`, note `WR3000P-FIX-20261112.txt`. Historical known-good pattern: `bak-dualfix-20261027`.

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
