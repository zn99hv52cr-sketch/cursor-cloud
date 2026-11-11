# AltStore «Server returned invalid response» (iTruba)

Date: 2026-09-02

## Symptom
AltServer on Windows: **Could not install AltStore to iTruba** → **Server returned invalid response**.

USB/pairing is fine (the device name is in the title). The failure is Apple signing (`gsa.apple.com` / `developerservices2.apple.com`), not the cable.

## Where it happened
Live on **Keenetic Air** (`sharpmaind2412`, Востряковский):

| Host | IP | Wi‑Fi |
|------|----|--------|
| iTruba | `192.168.2.128` | Volshebny Dom |
| Windows AltServer (`DESKTOP-0OH3R8Q`) | `192.168.2.80` | Volshebny Dom_5G |

AWG `Wireguard1` to FI `10.8.1.7` was **up**. Apple `17.0.0.0/8` already steered into the tunnel.

iTruba was **not** on Viva at this time.

## Cause
Router DNS upstream was **1.1.1.1 / 8.8.8.8 via ISP WAN**. In RU those resolvers are often intercepted. AltServer then talks to a fake/HTML Apple endpoint and maps it to **InvalidResponse**.

Apple IPv4 (`17/8`) was already via AWG; that does not help if **the name lookup itself** is poisoned.

## Live change (saved)
On **Air** and **Viva**, `/32` via `Wireguard1`:

- `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, `8.8.4.4`

On **Air** `awg-fi` also: `gsa.apple.com`, `developerservices2.apple.com`, `idmsa.apple.com`, `setup.icloud.com` (belt-and-suspenders; `include apple.com` already covers most).

No secrets in this note.

## Retry on the PC
1. On iTruba turn **off** Happ / v2raytun for the install.
2. USB cable, Trust this computer.
3. iTunes + iCloud **from apple.com**, not Microsoft Store; both running.
4. AltServer **Run as administrator**.
5. Install again (Apple ID).

If it still dies: join the Windows PC to **iTruba personal hotspot**, USB still plugged — known workaround when GSA is still weird on the LAN.

Windows AltServer also has a separate 2026 bug (`-22410` / `1100`); hotspot+USB is the practical bypass for that too.

## Follow-up — HDrezka `NSCocoaErrorDomain 3840`

AltStore itself installed. Installing **HDrezka** from AltStore on the phone then failed:

`Install HDrezka Failed` — `NSCocoaErrorDomain 3840` — «The data couldn’t be read because it isn’t in the correct format.»

Same class of bug: AltStore/AltServer got **HTML** (block page / GSA 401 page) instead of Apple plist/JSON while **signing a new app**. Cable does not skip Apple. Source JSON already loaded (the app is listed), so this is sign/IPA fetch, not “source missing”.

Extra live change on **Air**: GitHub prefixes via `Wireguard1` (`140.82.112.0/20`, `192.30.252.0/22`, `185.199.108.0/22`, `143.55.64.0/20`). `github.com` was already in `awg-fi`.

Retry: Happ **off**, **cellular off** (Wi‑Fi Assist), AltServer + iTunes/iCloud running, USB in. If 3840 stays: PC on iTruba hotspot + USB again.
