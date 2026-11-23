#!/bin/sh
# ON ROUTER: create backup. If TG_UPLOAD_URL is set, POST tarball there (optional relay).
# Typical: run backup here, then on VPS: tr3000-send-backup-telegram.sh
set -e
PATH=/usr/sbin:/usr/bin:/sbin:/bin
BASE="https://raw.githubusercontent.com/zn99hv52cr-sketch/cursor-cloud/cursor/fi-vps-outage-runbook-dead/ops/scripts"

curl -fsSL "$BASE/tr3000-backup-full.sh" | sh
OUT="$(ls -t /tmp/tr3000-backup-*.tar.gz 2>/dev/null | head -1)"
[ -n "$OUT" ] || { echo "backup failed"; exit 1; }

echo ""
echo "Backup: $OUT"
echo "Next — on PC:"
echo "  scp root@192.168.2.1:$OUT ."
echo "On FI VPS (@Vpn_sharpmaind_bot):"
echo "  scp tr3000-backup-*.tar.gz root@193.124.224.248:/tmp/"
echo "  CHAT_ID=186409737 /tmp/send-bak.sh /tmp/tr3000-backup-*.tar.gz"
echo ""
echo "Or send handoff+backup instructions doc to TG:"
echo "  CHAT_ID=186409737 send-tr3000-handoff-telegram.sh"