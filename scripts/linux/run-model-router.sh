#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${MODEL_ROUTER_INSTALL_DIR:-/opt/tailscale-ai-guide}"
TAILSCALE_BIN="${TAILSCALE_BIN:-/usr/bin/tailscale}"
ROUTER_PORT="${MODEL_ROUTER_PORT:-18180}"
ROUTER_HOST="${MODEL_ROUTER_HOST:-}"

if [[ -z "${ROUTER_HOST}" ]]; then
  for _ in $(seq 1 30); do
    ROUTER_HOST="$(${TAILSCALE_BIN} ip -4 2>/dev/null | head -n 1 || true)"
    [[ -n "${ROUTER_HOST}" ]] && break
    sleep 2
  done
fi

if [[ -z "${ROUTER_HOST}" ]]; then
  echo "ERROR: No Tailscale IPv4 address is available for the router listener." >&2
  exit 1
fi

exec "${INSTALL_DIR}/.venv/bin/uvicorn" \
  router.model_router:app \
  --host "${ROUTER_HOST}" \
  --port "${ROUTER_PORT}"
