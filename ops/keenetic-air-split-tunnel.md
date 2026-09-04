# Keenetic Air (`sharpmaind2412`) — split-tunnel trim

Date: 2026-09-01

## Goal
Unload CPU on Keenetic Air KN-1613 while keeping **YouTube, Telegram, Instagram, WhatsApp** via AmneziaWG (`Wireguard1` / AWG-FI → `10.8.1.7`).

## Cause
Router sat at **~100% CPU**. Load is AmneziaWG ASC crypto on traffic steered into the tunnel, not the route table itself. Oversized prefixes (Apple `17.0.0.0/8`, GCP `34.64.0.0/10`, `35.184.0.0/13`) pulled a lot of unrelated traffic into encryption.

## Removed from `Wireguard1`
- `17.0.0.0/8` (Apple)
- `34.64.0.0/10` (GCP)
- `35.184.0.0/13` (GCP)
- `66.220.0.0/16` (too broad Meta)

## Kept / added
**Telegram:** `91.108.4.0/22`, `91.108.8.0/22`, `91.108.12.0/22`, `91.108.16.0/22`, `91.108.20.0/22`, `91.108.56.0/22`, `91.105.192.0/23`, `95.161.64.0/20`, `149.154.160.0/20`, `185.76.151.0/24`

**YouTube / Google:** `64.233.160.0/19`, `74.125.0.0/16`, `142.250.0.0/16`, `142.251.0.0/16`, `172.217.0.0/16`, `172.253.0.0/16`, `173.194.0.0/16`, `108.177.0.0/17`, `192.178.0.0/16`, `209.85.128.0/17`, `216.58.0.0/16`, `216.239.32.0/19`, `66.102.0.0/20`, `130.211.0.0/16`

**Instagram / WhatsApp (Meta):** `31.13.0.0/16`, `157.240.0.0/16`, `69.171.224.0/19`, `129.134.0.0/16`, `173.252.64.0/18`, `66.220.144.0/20` (tightened), plus `185.60.216.0/22`, `179.60.192.0/22`

## Also on this pass
- `Wireguard0` left **down** (dead old endpoint)
- AWG peer keepalive set to **15s**
- VPS Kuma monitor retargeted to Air peer `10.8.1.7` (was wrongly watching `10.8.1.8`)

## Expectation
CPU may stay high while YouTube/Google ranges are still large (needed for YT). Relief comes from no longer encrypting Apple/GCP bulk. If still pegged, next step is further Google narrowing or a stronger router.

## Follow-up 2026-09-01 — Wi‑Fi (Vostryakovsky)
A/B: `Wireguard1` down did **not** drop CPU (still ~100%). Process **`ndm` ~84–98%**.

Wi‑Fi change applied and saved:
- was: channel **12**, width **40-below**, bitrate 300 Mbit, busy 6–13
- now: channel **1**, width **20**, bitrate 144 Mbit, busy 1–3

Overall `cpuload` still ~100% after change; `ndm` cur fluctuates lower at times. Next candidate: Keenetic Cloud / netcraze agent.

## Follow-up 2026-09-02 — draft firmware update
Checked AWG survival on draft catalog first: `wireguard` component present and queued for **5.2 Alpha 7** (`5.02.A.7.0-0`). ASC is part of Keenetic WireGuard since 4.2+.

Updated Air draft **5.1.1 → 5.2 Alpha 7**. After reboot:
- `Wireguard1` / AWG-FI **up**, peer online, ASC line unchanged
- VPS handshake OK
- CPU samples dropped off the permanent 100% peg (seen ~6–52% while settling)

Running-config backup kept on VPS as `air-rc-backup-pre-5.2A7-*.txt`.

## Follow-up 2026-09-02 — other routers
- **Viva / Вилиса Лациса** (`sharpmaind.netcraze.pro`, KN-1910): draft **5.1.1 → 5.2 Alpha 7**. FI-AWG (`10.8.1.4`) up, ASC preserved, VPS handshake OK.
- **Skipper / дача** (`sharpmind.netcraze.pro`, KN-2910): was stable 5.1.1; switched to draft and `components commit` to 5.2 Alpha 7 started (`update task started`, wireguard queued). Cloud stayed **503** afterward; polling stopped per request. Confirm locally later when cloud/admin is back.
- Config backups: `/root/rc-vilisa-viva.txt`, `/root/rc-dacha-skipper.txt` on FI VPS.

## Follow-up 2026-09-04 — TV YouTube / rutor.is (Востряковский Air vs Лацис Viva)

**Symptom:** on Air Wi‑Fi, Smart TV YouTube failed while iOS worked; `rutor.is` also failed.

**Root cause:** Air already had FQDN group `awg-fi` + `dns-proxy route object-group awg-fi Wireguard1` (youtube/googlevideo/rutor/…). iOS uses router DNS → FQDN policy works. Many TVs use their own DNS/DoH → FQDN never sees queries, so traffic needs **IP statics**. Gaps vs Viva (Лацис) YouTube/rutor coverage: `142.251/16`, `108.177/17`, `172.253/16`, `192.178/16`, `216.239.32/19`, `66.102/20`, `130.211/16`, and rutor `193.46.255.0/24` (`rutor.is` → `193.46.255.26`).

**Applied on Air (saved):** those eight prefixes via `Wireguard1` (WG1 statics ~40 → ~44). Did **not** copy Viva’s ~1000-prefix dump (CPU risk on KN-1613). FQDN `awg-fi` already matches Viva `vpn-sites` for youtube/rutor; aliases `youtu.be` / `youtube-nocookie.com` present (121 includes). Spot-check 2026-09-04 ~06:53Z: routes persisted after save; WG1 up/online; **cpuload 100%** (full process sample deferred to later timer).

**Note:** Viva keeps a huge IP list + `vpn-sites` FQDN; Air stays curated IP + rich FQDN. For TV apps, IP statics matter more than FQDN.
