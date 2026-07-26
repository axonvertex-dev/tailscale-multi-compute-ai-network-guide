#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "ERROR: tailscale CLI was not found." >&2
  exit 1
fi

if ! systemctl list-unit-files | grep -q '^ollama.service'; then
  echo "ERROR: ollama.service was not found." >&2
  exit 1
fi

TAILSCALE_IP="$(tailscale ip -4 | head -n 1)"
if [[ -z "${TAILSCALE_IP}" ]]; then
  echo "ERROR: No Tailscale IPv4 address is available." >&2
  exit 1
fi

install -d -m 0755 /etc/systemd/system/ollama.service.d
cat >/etc/systemd/system/ollama.service.d/override.conf <<EOF_INNER
[Service]
Environment="OLLAMA_HOST=${TAILSCALE_IP}:11434"
EOF_INNER

systemctl daemon-reload
systemctl restart ollama
systemctl status ollama --no-pager

echo
echo "Ollama now listens on ${TAILSCALE_IP}:11434."
echo "Keep port 11434 restricted with Tailscale grants and the host firewall."
