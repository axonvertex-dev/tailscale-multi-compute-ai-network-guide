#!/usr/bin/env bash
set -euo pipefail

TS_BIN="$(command -v tailscale || true)"
if [[ -z "$TS_BIN" && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
  TS_BIN=/Applications/Tailscale.app/Contents/MacOS/Tailscale
fi

if [[ -z "$TS_BIN" ]]; then
  echo "ERROR: Tailscale CLI was not found. Install CLI integration from Tailscale Settings." >&2
  exit 1
fi

echo "Using: $TS_BIN"
"$TS_BIN" version
"$TS_BIN" status
"$TS_BIN" ip -4
"$TS_BIN" netcheck
