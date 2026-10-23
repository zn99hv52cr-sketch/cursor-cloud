#!/usr/bin/env bash
# Remnawave: verify/fix Emil Beeline squads and hosts. Run on FI VPS as root.
set -euo pipefail

APPLY=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    -h|--help)
      echo "Usage: $0 [--apply]   # default: dry-run report only"
      exit 0
      ;;
  esac
done

JWT="${REMNAWAVE_JWT:-}"
for f in /opt/remnawave/remnawave-vpn-bot.jwt /root/creds/remnawave-vpn-bot.jwt; do
  [[ -z "$JWT" && -f "$f" ]] && JWT="$(cat "$f")"
done
[[ -n "$JWT" ]] || { echo "No JWT (set REMNAWAVE_JWT or place jwt file on VPS)"; exit 1; }

BASE="https://vpn2.sharpmaind.ru"
api() {
  local method=$1 path=$2
  shift 2
  curl -fsS --resolve vpn2.sharpmaind.ru:443:127.0.0.1 \
    -X "$method" -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    "$BASE$path" "$@"
}

echo "=== Emil users ==="
for u in Emil_1 Emil_2 Emil_3 Emil_4 Emil_5 Emil_6; do
  api GET "/api/users/by-username/$u" | python3 -c "
import sys,json
r=json.load(sys.stdin).get('response',{})
t=r.get('userTraffic') or {}
print('$u', 'status=', r.get('status'), 'squads=', r.get('activeInternalSquads') or r.get('internalSquads'), 'onlineAt=', t.get('onlineAt'))
"
done

echo ""
echo "=== Squads (Emil / happ / beeline) ==="
api GET "/api/internal-squads" -o /tmp/squads.json 2>/dev/null || api GET "/api/squads" -o /tmp/squads.json
python3 << 'PY'
import json
data=json.load(open("/tmp/squads.json"))
items=data.get("response",{}).get("internalSquads") or data.get("response") or []
for s in items:
    name=(s.get("name") or "")
    if any(x in name.lower() for x in ["emil","happ","beeline","default"]):
        print(name, "uuid=", s.get("uuid") or s.get("id"))
PY

echo ""
echo "=== Beeline hosts (Emil-Beeline / packet-up) ==="
api GET "/api/hosts" -o /tmp/hosts.json
python3 << 'PY'
import json
h=json.load(open("/tmp/hosts.json")).get("response",[])
keys=("beeline","билайн","packet","emil")
for x in sorted(h, key=lambda z: (z.get("viewPosition") or 999, z.get("remark") or "")):
    rem=(x.get("remark") or "")
    if not any(k in rem.lower() for k in keys):
        continue
    dis=x.get("isDisabled") is True or x.get("enabled") is False
    print(f"pos={x.get('viewPosition')} disabled={dis} remark={rem} path={x.get('path')} alpn={x.get('alpn')}")
PY

if [[ "$APPLY" != true ]]; then
  echo ""
  echo "Dry-run only. Re-run with --apply after reviewing panel API patch procedures manually."
  echo "Typical fix: enable isDisabled=false on Beeline packet-up* hosts; Emil_1..5 only Emil-Beeline; Emil_6 only happ."
  exit 0
fi

echo ""
echo "Apply mode: host/user PATCH must be done via panel or documented API — script reports only until PATCH endpoints are wired."
exit 0
