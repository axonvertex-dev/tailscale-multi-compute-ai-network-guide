#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

if ! systemctl list-unit-files | grep -q '^ollama.service'; then
  echo "ERROR: ollama.service was not found." >&2
  exit 1
fi

install -d -m 0755 /etc/systemd/system/ollama.service.d
cat >/etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

systemctl daemon-reload
systemctl restart ollama
systemctl status ollama --no-pager

echo
echo "Ollama now listens on 0.0.0.0:11434."
echo "Do not open port 11434 publicly. Restrict access with the host firewall and Tailscale grants."
