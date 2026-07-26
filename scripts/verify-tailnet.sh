#!/usr/bin/env bash
set -euo pipefail

if ! command -v tailscale >/dev/null 2>&1; then
  echo "ERROR: tailscale CLI was not found." >&2
  exit 1
fi

echo "== Tailscale version =="
tailscale version

echo
echo "== Local Tailscale IPv4 =="
tailscale ip -4

echo
echo "== Tailnet status =="
tailscale status

echo
echo "== Network check =="
tailscale netcheck

echo
echo "== DNS status =="
tailscale dns status || true

echo
echo "Verification complete. Review any relay, DNS, or authentication warnings above."
