#!/usr/bin/env bash
# Cloud Agent: join tailnet on boot and stay ready for `tailscale ssh` to Cudy routers.
set -euo pipefail

mkdir -p /tmp/cursor
TS_STATE_DIR="${TAILSCALE_STATE_DIR:-/var/lib/tailscale}"
TS_SOCKET="${TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
TS_HOSTNAME="${TAILSCALE_HOSTNAME:-cursor-cloud}"

if ! command -v tailscaled >/dev/null 2>&1; then
	echo "start-tailscale: tailscaled missing (install phase should install it)" >&2
	exit 0
fi

sudo mkdir -p /var/run/tailscale "$TS_STATE_DIR"

if ! pgrep -x tailscaled >/dev/null 2>&1; then
	sudo tailscaled \
		--state="${TS_STATE_DIR}/tailscaled.state" \
		--socket="$TS_SOCKET" \
		>>/tmp/cursor/start-tailscale.log 2>&1 &
	for _ in $(seq 1 30); do
		sudo tailscale --socket="$TS_SOCKET" status >/dev/null 2>&1 && break
		sleep 1
	done
fi

if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
	echo "start-tailscale: TAILSCALE_AUTHKEY not set; skipping tailscale up" >>/tmp/cursor/start-tailscale.log
	exit 0
fi

# Re-auth with key so every fresh VM joins without a browser link.
sudo tailscale --socket="$TS_SOCKET" up \
	--auth-key="$TAILSCALE_AUTHKEY" \
	--hostname="$TS_HOSTNAME" \
	--accept-routes \
	--ssh \
	>>/tmp/cursor/start-tailscale.log 2>&1 || true

sudo tailscale --socket="$TS_SOCKET" status >>/tmp/cursor/start-tailscale.log 2>&1 || true
