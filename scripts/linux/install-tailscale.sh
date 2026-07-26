#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a normal sudo-capable user, not directly as root." >&2
  exit 1
fi

curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled

echo
echo "Tailscale is installed. Authenticate with:"
echo "  sudo tailscale up"
echo
echo "For a tagged server, define the tag in policy and use a controlled auth key."
