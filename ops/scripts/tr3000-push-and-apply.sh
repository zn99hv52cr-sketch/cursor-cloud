#!/bin/bash
# Run from Cloud Agent: deploy + apply HDrezka MiTV fix on TR when SSH is up.
set -euo pipefail
KEY="${HOME}/.ssh/wr3000p_ed25519"
HOST="${TR_HOST:-100.81.160.52}"
REPO="$(cd "$(dirname "$0")" && pwd)"

ssh_tr() {
  ssh -p 2222 -i "$KEY" -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new "root@${HOST}" "$@"
}

for attempt in $(seq 1 "${ATTEMPTS:-60}"); do
  echo "=== attempt $attempt ==="
  if ssh_tr 'echo PING'; then
    base64 -w0 "$REPO/tr3000-wan-recover.sh" | ssh_tr "base64 -d > /usr/bin/tr3000-wan-recover && chmod +x /usr/bin/tr3000-wan-recover"
    base64 -w0 "$REPO/tr3000-podkop-restore-mangle.sh" | ssh_tr "base64 -d > /usr/bin/podkop-restore-mangle.sh && chmod +x /usr/bin/podkop-restore-mangle.sh"
    base64 -w0 "$REPO/tr3000-hdrezka-mitv-apply.sh" | ssh_tr "base64 -d > /tmp/tr3000-hdrezka-mitv-apply.sh && chmod +x /tmp/tr3000-hdrezka-mitv-apply.sh && sh /tmp/tr3000-hdrezka-mitv-apply.sh"
    ssh_tr 'nft list chain inet PodkopTable mangle | grep counter | head -2; ip route get 198.18.0.15 from 192.168.2.145 iif br-lan; pidof sing-box'
    exit 0
  fi
  sleep "${INTERVAL:-30}"
done
exit 1