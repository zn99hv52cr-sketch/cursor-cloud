# LuCI dashboard on Cudy TR3000

Same «Информационная панель» as WR3000P (`100.104.207.62`). Official OpenWrt package `luci-mod-dashboard`, not a custom theme.

## Applied 2026-10-16

TR3000 `100.81.160.52`, OpenWrt 25.12.5 (`r33051-f5dae5ece4`), same arch as WR3000P (`aarch64_cortex-a53`). Overlay had ~4.3 MiB free (90%). Package is ~59 KiB + 4 KiB RU i18n.

```sh
apk update
apk add luci-mod-dashboard luci-i18n-dashboard-ru
/etc/init.d/rpcd restart
/etc/init.d/uhttpd reload
```

Verified: `/usr/share/luci/menu.d/luci-mod-dashboard.json` (`admin/dashboard`, order 1), `http://127.0.0.1/luci-static/resources/view/dashboard/index.js` HTTP 200. sing-box / `podkop-tun-watch` / tailscaled left running. Overlay after: 4.4 MiB free.

Open LuCI (LAN `192.168.2.1` or Tailscale `https://100.81.160.52/`), пункт **Информационная панель** / Dashboard — трафик WAN, CPU/RAM, аптайм, DHCP.

После полного sysupgrade пакет не в образе — снова `apk add luci-mod-dashboard luci-i18n-dashboard-ru`. Reboot overlay сохраняет.
