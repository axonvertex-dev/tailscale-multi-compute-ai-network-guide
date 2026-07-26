#!/usr/bin/env bash
set -u

PRIMARY_URL="${PRIMARY_MODEL_URL:-http://axonvertex-01:18181}"
SECONDARY_URL="${SECONDARY_MODEL_URL:-http://axonvertex-personal-01:11434}"
MAC_URL="${MAC_MLX_URL:-http://rentorzos-macbook-pro-2:18181}"
ROUTER_URL="${MODEL_ROUTER_URL:-http://rentorzos-macbook-pro-2:18180}"
AUTH_HEADER=()

if [[ -n "${ROUTER_API_KEY:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${ROUTER_API_KEY}")
fi

check() {
  local name="$1"
  local url="$2"
  shift 2
  echo "== ${name} =="
  if curl -fsS --connect-timeout 5 --max-time 15 "$@" "$url"; then
    echo
    echo "PASS: ${url}"
  else
    echo
    echo "FAIL: ${url}" >&2
  fi
  echo
}

check "Primary OpenAI-compatible model" "${PRIMARY_URL}/v1/models"
check "Secondary Ollama model" "${SECONDARY_URL}/api/tags"
check "Mac MLX model" "${MAC_URL}/v1/models"
check "Central router" "${ROUTER_URL}/health" "${AUTH_HEADER[@]}"
