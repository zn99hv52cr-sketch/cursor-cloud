# YouTube EE logo and ads after 2026-10-15 netplan

2026-10-16. After the Oct 15 “bind only `185.141.217.43`” change, YouTube showed **EE** next to the logo and started serving ads. Seen on the home WR3000P path and by a VPN subscriber. Same VLESS node, not a client bug.

## Cause

Google/YouTube geo of the two AdminVPS addresses (checked with `curl` source bind, `GL` / `hl` in the homepage):

| Source IP | YouTube `GL` | `hl` |
|-----------|--------------|------|
| `193.124.224.248` | **RU** | ru |
| `185.141.217.43` | **EE** | et |

Oct 15 netplan left only `.43/24` as default source (gateway `185.141.217.1` is on that subnet). Xray `remnanode` uses host network, so every tunnel exit became `.43` → Estonian YouTube → ads. Russian YouTube on `.248` had been serving without those ads.

`.43` must stay on the box: that is the RU-reachable inbound. `.248` is still routed to the VM; it was only missing from the OS.

## Applied

- `/etc/netplan/60-extra-ip.yaml`: both `185.141.217.43/24` and `193.124.224.248/32`, default still via `185.141.217.1`. Backup `/root/backups/netplan-20261016-youtube-ee/`.
- `egress-src-248.service`: after `network-online`, `ip route replace default via 185.141.217.1 dev eth0 src 193.124.224.248` (netplan would otherwise pick `.43` as src because it sits on the gateway subnet).
- Did **not** restart remnanode / Caddy / the VPS. Listeners stay on `*:443`.

## Check

```sh
ip -4 route show default    # src 193.124.224.248
curl -4 -sS https://ifconfig.me/ip   # 193.124.224.248
# YouTube HTML: "GL":"RU"  "hl":"ru"
curl -sk --resolve vpn2.sharpmaind.ru:443:185.141.217.43 https://vpn2.sharpmaind.ru/  # inbound .43 still up
```

Verified 2026-10-16: VPS egress `.248`, YouTube `GL=RU`; through WR3000P VLESS YouTube `GL=RU` HTTP 200; Instagram/Telegram 200; `api2.cursor.sh` 200; `vpn2` on `.43` HTTP 401 (Caddy up). Clients should refresh YouTube (or clear cookies) if the EE badge is cached.
