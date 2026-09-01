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

**YouTube / Google:** `64.233.160.0/19`, `74.125.0.0/16`, `142.250.0.0/16`, `172.217.0.0/16`, `173.194.0.0/16`, `209.85.128.0/17`, `216.58.0.0/16`

**Instagram / WhatsApp (Meta):** `31.13.0.0/16`, `157.240.0.0/16`, `69.171.224.0/19`, `129.134.0.0/16`, `173.252.64.0/18`, `66.220.144.0/20` (tightened), plus `185.60.216.0/22`, `179.60.192.0/22`

## Also on this pass
- `Wireguard0` left **down** (dead old endpoint)
- AWG peer keepalive set to **15s**
- VPS Kuma monitor retargeted to Air peer `10.8.1.7` (was wrongly watching `10.8.1.8`)

## Expectation
CPU may stay high while YouTube/Google ranges are still large (needed for YT). Relief comes from no longer encrypting Apple/GCP bulk. If still pegged, next step is further Google narrowing or a stronger router.
