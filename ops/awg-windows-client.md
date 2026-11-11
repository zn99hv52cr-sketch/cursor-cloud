# AmneziaWG Windows client

Date: 2026-09-02

Official client (not stock WireGuard): [amnezia-vpn/amneziawg-windows-client](https://github.com/amnezia-vpn/amneziawg-windows-client).

## Files
Latest **3.1.0** amd64 MSI (matches typical Windows 10/11 PC):

- https://github.com/amnezia-vpn/amneziawg-windows-client/releases/download/3.1.0/amneziawg-amd64-3.1.0.msi
- SHA256 `a1b48ea8699cd347832a3691d832004574ef8ad65bcf887611ac8acb99b7de8b`

Fallback if 3.1.0 will not handshake with the FI `amnezia-awg2` server: **2.0.2** amd64 from the same repo.

Save the MSI to the Windows Desktop, install, then import a `.conf` from the AWG panel (`awg.sharpmaind.ru`) — regular WireGuard cannot use Jc/Jmin/H1… obfuscation.

No secrets and no installer binaries in git.
