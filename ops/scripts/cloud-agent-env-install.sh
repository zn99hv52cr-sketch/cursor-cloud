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

# CUDY_TR3000_SSH_KEY is often the raw OpenSSH private key (env secret), not a path.
if [ -n "${CUDY_TR3000_SSH_KEY:-}" ] && [ ! -f "${CUDY_TR3000_SSH_KEY}" ]; then
	case "$CUDY_TR3000_SSH_KEY" in
		-----BEGIN*)
			install -d -m 700 "${HOME}/.ssh"
			install -m 600 /dev/stdin "${HOME}/.ssh/wr3000p_ed25519" <<<"$CUDY_TR3000_SSH_KEY"
			;;
	esac
fi
