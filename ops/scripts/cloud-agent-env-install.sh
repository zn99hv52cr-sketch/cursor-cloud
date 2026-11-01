#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap: tools for ops + Tailscale client.
set -euo pipefail

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sshpass curl ca-certificates
if ! command -v tailscale >/dev/null 2>&1; then
	curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

if [ ! -x .cursor/start-tailscale.sh ] && [ -f ops/scripts/cloud-agent-start-tailscale.sh ]; then
	mkdir -p .cursor
	cp ops/scripts/cloud-agent-start-tailscale.sh .cursor/start-tailscale.sh
	chmod +x .cursor/start-tailscale.sh
fi
