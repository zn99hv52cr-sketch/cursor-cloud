# Cudy TR3000 (OpenWrt) via Tailscale + podkop

## Access (Cloud / local agents)

- Tailscale IP only: `100.81.160.52` (hostname `cudy`)
- Home LAN: `192.168.2.1` — do **not** accept advertised `192.168.2.0/24` routes
- Connect agent:

```bash
tailscale up --auth-key="$TS_AUTHKEY" --hostname=cursor-agent --accept-routes=false --ssh
tailscale ssh root@100.81.160.52
```

- **MagicDNS on the router stays OFF.** Never switch to MagicDNS names for the router; keep `100.81.160.52`.
- Do **not** enable Tailscale Funnel.
- Auth key is reusable, ~90 days from creation (≈ until 2027-01-02). Re-run `tailscale up` each new agent session. When expired, ask the user for a new key.
- First `tailscale ssh` in a session may print `To authenticate, visit: https://login.tailscale.com/a/...` — user must open that URL once (Tailscale account). Not the Machines three-dot menu.

## Hardware / role

- Cudy TR3000, OpenWrt, weak CPU (2 cores; load ~2.0 ≈ 100%)
- `podkop` split: selected domains → VLESS via FI VPS; rest direct
- Battle.net: site / region check via tunnel; game download CDN stays **direct** (~7 MB/s tunnel vs gigabit VPS)

## podkop domains (do not remove older list)

Tunnel (`uci podkop.main.user_domains`, dynamic), includes Battle.net set:

`battle.net`, `battlenet.com`, `diabloimmortal.com`, `blz-contentstack.com`, `blznav.akamaized.net`, `blzmedia-a.akamaihd.net`, `bnetcmsus-a.akamaihd.net`, `bnetproduct-a.akamaihd.net`, `bnetshopus.akamaized.net`, `blizzcon-a.akamaihd.net`, `news.blizzard.com`, `static.blizzard.com`, `www.blizzard.com`, `eu.blizzard.com`, `us.blizzard.com`, `di.blizzard.com`, `diabloimmortal.blizzard.com`

Plus existing: rutracker/rutor/nnmclub, cursor*, anydesk, rezka/voidboost, hp*, etc.

**Never add** whole `blizzard.com` suffix. Keep **direct** (not in list):

- `level3.blizzard.com`
- `*.cdn.blizzard.com`
- `blzddist1-a.akamaihd.net`
- `blzddistkr1-a.akamaihd.net`

## Edit flow

```bash
# edit list
uci get podkop.main.user_domains
# ... uci add_list / del_list / set as needed ...
uci commit podkop
/etc/init.d/podkop restart
# if log says «sing-box configuration is unchanged»:
/etc/init.d/sing-box restart
```

Check from router:

```bash
nslookup NAME 127.0.0.1
# 198.18.x.x → tunnel; public IP → direct
```

## Verified 2026-10-04

- SSH via Tailscale OK after check approval
- `battle.net` / `www.blizzard.com` → `198.18.*` (tunnel)
- `level3.blizzard.com` / `blzddist1-a.akamaihd.net` → public Akamai (direct)
- Load low (~0.2)

## FI IP blackhole from RU (2026-10-04) — Cloudflare front

Home WAN `46.138.53.156` (MGTS) and Moscow check-host nodes cannot reach FI VPS `193.124.224.248` on **any** TCP port (22/80/443/8443). EU nodes OK. Remnawave/Caddy/Happ backend are healthy; the path is IP-blocked.

**Working temporary front (quick tunnel):**

- VPS: `cloudflared tunnel --url http://127.0.0.1:8080` + docker `cf-front` (Caddy HTTP mux → remnawave `:3000`, WS `/vpn` → `:10443`, xHTTP `/xh` → `:10445`, gRPC → `:10444`)
- State/helpers: `/opt/cf-front/` (`public_url.txt`, `watchdog.sh` cron `*/2`, `update-hosts-to-current-url.sh`)
- Remnawave: all hosts `address/sni/host` = current `*.trycloudflare.com`; `SUB_PUBLIC_DOMAIN=<front>/api/sub`
- Cudy `podkop.main.proxy_string` → same CF host:443 (WS `/vpn`); FakeIP domains still tunnel via CF (MGTS can reach CF anycast)
- Happ: old `https://vpn2.sharpmaind.ru/api/sub/...` cannot refresh (DNS→dead IP). Users must **re-add** subscription from the trycloudflare URL (admin iTruba notified in TG)

**Verified:** Moscow check-host HTTP 200 on CF sub URL; VLESS via CF returns VPS egress IP.

**Permanent fix (needed):** AdminVPS new IP **or** Cloudflare orange-cloud / named tunnel + DNS for `vpn2.sharpmaind.ru` at reg.ru (quick tunnel URL changes on cloudflared restart — watchdog rewrites hosts). Backup of pre-change hosts: `/root/backups/cf-front-20261004/`.

Optional agent SSH `-R 127.0.0.1:10443:193.124.224.248:443` (tmux `vps-rforward`) remains a fallback if CF dies; not required while CF front works.
## IPv6

For this home setup (IPv4 LAN, podkop/VLESS, Tailscale) IPv6 is unnecessary.

Already mostly off (`sysctl` disable + `dhcpv6`/`ra` disabled). Cleaned 2026-10-04:
- removed `network.wan6`, ULA prefix
- `lan`/`wan` `delegate=0` and `ipv6=0`
- removed IPv6 firewall allow rules (DHCPv6/MLD/ICMPv6)
- removed stale `wan6` from `firewall` wan zone network list
- kept `/etc/sysctl.d/99-disable-ipv6.conf`

## Deep audit 2026-10-04 (vs OpenWrt / fw4)

**OK**

- OpenWrt `25.12.5` mediatek/filogic, uptime ~5d, load ~0.2–0.3, RAM fine
- `fw4` loaded (`nft table inet fw4`); procd may show firewall `stopped` / `active with no instances` — normal oneshot, not broken
- WAN input REJECT (DHCP renew / ping / IGMP only); LAN accept; masquerade + MTU fix on wan
- Tailscale zone + lan↔tailscale / tailscale→wan forwarding; MagicDNS `CorpDNS=false`, `RouteAll=false`, SSH on
- dnsmasq → `127.0.0.42` (sing-box); FakeIP works; Battle.net → `198.18.*`, CDN `level3` → public
- VLESS `main-out` delay ~120 ms via Clash API; `https://vpn2.sharpmaind.ru` from router HTTP 200 ~30 ms
- `sing-box` UCI `enabled=0` but process running — expected (podkop starts it; do not enable both)
- Wi‑Fi 2.4/5 up, WPA2-PSK

**WARN**

- Overlay **90%** used (~4 MB free). Biggest: `sing-box` ~42 MB + `tailscaled` ~25 MB on flash. Avoid more packages; watch before `opkg upgrade`
- Intermittent historical `dial tcp 193.124.224.248:443: i/o timeout` in sing-box logs (seen around WAN flap / IPv6 cleanup). Live path OK now — do not trust BusyBox `nc` (no `-w` / `/dev/tcp`)
- `odhcpd` still running while DHCPv6/RA disabled — harmless waste; can `disable` if desired
- Dropbear password + root password auth on; WAN firewall blocks 22 from eth0, but prefer keys long-term
- LuCI `uhttpd` listens `0.0.0.0:80/443` — OK behind wan REJECT + `rfc1918_filter=1`

**Notes**

- Router advertises Tailscale routes `192.168.2.0/24` (+ `192.168.1.254/32`); agents must keep `--accept-routes=false`
- PodkopTable mangle/proxy chains empty in TUN mode — routing via FakeIP `198.18.0.0/15` + subnet routes on `sbtun`, not nft redirect

Do not commit Tailscale auth keys or VLESS URLs.
