# Keenetic Viva — Cursor / AnyDesk via FI-AWG

**Router:** Viva KN-1910 (`sharpmaind.netcraze.pro`), Home `192.168.1.1`, AWG `Wireguard1` / FI-AWG → `10.8.1.4`

**Symptom:** on a PC on Viva LAN, Cursor and AnyDesk fail unless a VPN client is ON on that PC.

**Cause:** apps often skip router DNS (DoH / hard-coded IPs). FQDN policy `vpn-sites` alone is not enough — need **IP statics** via `Wireguard1`, especially Cloudflare + AWS ranges used by Cursor API.

**Remote note (2026-10-04):** Keenetic Cloud RCI via `sharpmaind.netcraze.pro` times out (`0x2027` / HttpClient Timeout). Apply **from the PC on Viva LAN** at `http://192.168.1.1` (fast). Login `admin`.

## One-shot (browser console on local admin)

1. On the PC connected to Viva Wi‑Fi/LAN open **`http://192.168.1.1`** and log in.
2. F12 → Console → paste the script below → Enter.
3. Wait for `DONE {ok:…}` then fully restart Cursor and AnyDesk.

```javascript
(async () => {
  const routes = [
    ["92.223.88.0","255.255.255.0"],
    ["195.181.160.0","255.255.240.0"],
    ["185.229.0.0","255.255.0.0"],
    ["141.95.128.0","255.255.128.0"],
    ["76.76.0.0","255.255.0.0"],
    ["100.56.0.0","255.255.0.0"],
    ["32.193.0.0","255.255.0.0"],
    ["148.113.0.0","255.255.0.0"],
    ["104.16.0.0","255.240.0.0"],
    ["172.64.0.0","255.248.0.0"],
    ["52.0.0.0","255.224.0.0"],
    ["52.192.0.0","255.224.0.0"],
    ["54.64.0.0","255.224.0.0"],
    ["54.160.0.0","255.224.0.0"],
    ["54.192.0.0","255.224.0.0"],
    ["54.224.0.0","255.224.0.0"],
    ["100.16.0.0","255.240.0.0"],
    ["100.48.0.0","255.240.0.0"],
    ["34.192.0.0","255.192.0.0"],
    ["13.248.0.0","255.252.0.0"],
    ["18.192.0.0","255.254.0.0"],
    ["18.194.0.0","255.254.0.0"],
    ["18.196.0.0","255.254.0.0"],
    ["18.198.0.0","255.254.0.0"],
    ["18.200.0.0","255.248.0.0"],
    ["18.208.0.0","255.240.0.0"],
    ["18.224.0.0","255.248.0.0"],
    ["18.232.0.0","255.252.0.0"],
    ["35.71.0.0","255.255.0.0"],
    ["35.144.0.0","255.240.0.0"],
    ["35.168.0.0","255.248.0.0"],
    ["44.192.0.0","255.224.0.0"],
    ["98.80.0.0","255.240.0.0"],
    ["3.208.0.0","255.240.0.0"],
    ["3.224.0.0","255.240.0.0"],
    ["44.196.0.0","255.252.0.0"],
    ["44.218.0.0","255.255.0.0"],
  ];
  const fqdns = ["anydesk.com","net.anydesk.com","cursorapi.com","todesktop.com","workos.com","cursor.com","cursor.sh"];
  async function p(body) {
    const r = await fetch("/rci/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify(body),
    });
    const t = await r.text();
    console.log(r.status, body.parse || "save", t.slice(0, 120));
    if (!r.ok) throw new Error(t || String(r.status));
  }
  let ok = 0;
  for (const [ip, mask] of routes) {
    await p({ parse: `ip route ${ip} ${mask} Wireguard1 auto` });
    ok++;
  }
  for (const d of fqdns) {
    await p({ parse: `object-group fqdn vpn-sites include ${d}` });
    ok++;
  }
  await p({ parse: "dns-proxy route object-group vpn-sites Wireguard1" });
  await p({ system: { configuration: { save: true } } });
  console.log("DONE", { ok });
})();
```

## Manual UI (if console blocked)

**Network rules → Routing** (or **Internet → Other connections → FI-AWG** related routes): add destinations via interface **Wireguard1 / FI-AWG**, then **Save**.

Minimum set that usually unblocks Cursor+AnyDesk:

| Destination | Via |
|-------------|-----|
| `104.16.0.0/12` | Wireguard1 |
| `172.64.0.0/13` | Wireguard1 |
| `52.0.0.0/11` | Wireguard1 |
| `54.224.0.0/11` | Wireguard1 |
| `100.16.0.0/12` | Wireguard1 |
| `100.48.0.0/12` | Wireguard1 |
| `92.223.88.0/24` | Wireguard1 |
| `195.181.160.0/20` | Wireguard1 |
| `185.229.0.0/16` | Wireguard1 |
| `148.113.0.0/16` | Wireguard1 |

Also ensure FQDN group `vpn-sites` includes `cursor.com`, `cursor.sh`, `cursorapi.com`, `anydesk.com`, `net.anydesk.com` and `dns-proxy route object-group vpn-sites Wireguard1`.

## Optional PC tweak

If still region-blocked: disable IPv6 on the PC (AAAA can bypass IPv4 WG statics).

## Already on Viva (backup Sep 2026)

Base `!anydesk-cursor` / `!anydesk-relay` prefixes and `cursor.com` / `cursor.sh` FQDNs were present. Missing for reliable Cursor: broad CF/AWS covers (`104.16/12`, `172.64/13`, `52/11`, …) — same set that fixed Air.
