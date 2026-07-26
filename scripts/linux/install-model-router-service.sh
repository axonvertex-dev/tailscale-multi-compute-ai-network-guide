#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_DIR="/opt/tailscale-ai-guide"
SERVICE_USER="ai-router"
ENV_FILE="/etc/tailscale-ai-router.env"
UNIT_FILE="/etc/systemd/system/model-router.service"

for command_name in python3 tailscale systemctl tar openssl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null || true)" ]]; then
  echo "ERROR: Repository has uncommitted changes. Commit or stash them first." >&2
  exit 1
fi

if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
  useradd \
    --system \
    --home-dir "${INSTALL_DIR}" \
    --shell /usr/sbin/nologin \
    "${SERVICE_USER}"
fi

install -d -o root -g "${SERVICE_USER}" -m 0750 "${INSTALL_DIR}"

tar \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='.env' \
  --exclude='__pycache__' \
  -C "${REPO_ROOT}" \
  -cf - . | tar -C "${INSTALL_DIR}" -xf -

if [[ ! -f "${INSTALL_DIR}/config/models.yaml" ]]; then
  cp \
    "${INSTALL_DIR}/config/models.example.yaml" \
    "${INSTALL_DIR}/config/models.yaml"
  echo "Created ${INSTALL_DIR}/config/models.yaml from the example."
  echo "Edit its backend URLs and model names before production use."
fi

python3 -m venv "${INSTALL_DIR}/.venv"
"${INSTALL_DIR}/.venv/bin/pip" install --upgrade pip
"${INSTALL_DIR}/.venv/bin/pip" install \
  -r "${INSTALL_DIR}/router/requirements.txt"

if [[ ! -f "${ENV_FILE}" ]]; then
  ROUTER_SECRET="$(openssl rand -hex 32)"
  cat >"${ENV_FILE}" <<EOF_ENV
MODEL_ROUTER_CONFIG=${INSTALL_DIR}/config/models.yaml
ROUTER_API_KEY=${ROUTER_SECRET}
ROUTER_REQUEST_TIMEOUT_SECONDS=120
ROUTER_HEALTH_TIMEOUT_SECONDS=5
ROUTER_LOG_LEVEL=INFO
MODEL_ROUTER_PORT=18180
ALLOW_INSECURE_NO_AUTH=false
EOF_ENV
fi

chown root:"${SERVICE_USER}" "${ENV_FILE}"
chmod 0640 "${ENV_FILE}"
chown -R root:"${SERVICE_USER}" "${INSTALL_DIR}"
chmod -R g+rX,o-rwx "${INSTALL_DIR}"
chmod 0750 \
  "${INSTALL_DIR}/scripts/linux/run-model-router.sh" \
  "${INSTALL_DIR}/scripts/linux/install-model-router-service.sh"

install -o root -g root -m 0644 \
  "${INSTALL_DIR}/router/systemd/model-router.service" \
  "${UNIT_FILE}"

systemctl daemon-reload
systemctl enable --now model-router.service
systemctl status model-router.service --no-pager

echo
echo "Model router service installed."
echo "Environment file: ${ENV_FILE}"
echo "Read the generated API key with:"
echo "  sudo grep '^ROUTER_API_KEY=' ${ENV_FILE}"
