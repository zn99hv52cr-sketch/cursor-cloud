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
- `egress-src-248.service` + `/usr/local/sbin/egress-src-248.sh`: after `network-online`, set default src `.248`, and SNAT docker/AWG ranges (`172.17/16`, `172.18/16`, `172.20/16`, `172.29.172/24`, `10.0.0/24`, `10.8.1/24`) to `.248`. Do **not** SNAT all of `eth0` — that would break replies to inbound `.43`.
- Did **not** restart remnanode / Caddy / the VPS. Listeners stay on `*:443`.

VLESS (`remnanode` host network) already used the kernel default src. AmneziaWG sits in docker and was still MASQUERADE to `.43` until the SNAT rules; `docker exec amnezia-awg2 curl ifconfig.me` now returns `.248`.

## Check

```sh
ip -4 route show default    # src 193.124.224.248
curl -4 -sS https://ifconfig.me/ip   # 193.124.224.248
# YouTube HTML: "GL":"RU"  "hl":"ru"
curl -sk --resolve vpn2.sharpmaind.ru:443:185.141.217.43 https://vpn2.sharpmaind.ru/  # inbound .43 still up
```

Verified 2026-10-16: host and AWG-netns egress `.248`, YouTube `GL=RU`; through WR3000P VLESS YouTube `GL=RU` HTTP 200; Instagram/Telegram 200; `vpn2` on `.43` HTTP 401. Clients should refresh YouTube (or clear cookies) if the EE badge is cached.

This is YouTube’s RU geo of `.248`, not an adblocker. If Google retags the IP, ads can return. NL node (`147.45.111.81`) is a different exit and is unchanged.
