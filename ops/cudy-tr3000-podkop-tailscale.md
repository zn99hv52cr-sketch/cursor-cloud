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

Do not commit Tailscale auth keys or VLESS URLs.
