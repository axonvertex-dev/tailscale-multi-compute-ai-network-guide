# Linux Model Router Service

This guide installs the reference model router as a hardened systemd service on an Ubuntu or Debian compute node connected to the tailnet.

## 1. Prerequisites

The Linux host must have:

- Tailscale installed and connected.
- A working Tailscale IPv4 address.
- Python 3 with the `venv` module.
- `openssl`, `tar`, and systemd.
- Reachable model backends declared in `config/models.yaml`.

This repository does not install model runtimes or model weights.

## 2. Prepare the routing configuration

From the repository root:

```bash
cp config/models.example.yaml config/models.yaml
nano config/models.yaml
```

Replace the example backend URLs, providers, model names, capabilities, and health paths with the actual services on the tailnet.

The local `config/models.yaml` file is ignored by Git so deployment-specific routing details are not committed accidentally.

## 3. Validate Tailscale and the repository

```bash
tailscale status
tailscale ip -4
make validate
git status
```

Commit or stash any intended repository changes before running the installer.

## 4. Install the service

```bash
sudo bash scripts/linux/install-model-router-service.sh
```

The installer:

1. Creates the `ai-router` system account.
2. Copies the repository to `/opt/tailscale-ai-guide` without `.git`, `.venv`, or `.env`.
3. Creates a Python virtual environment.
4. Installs the router requirements.
5. Creates `/etc/tailscale-ai-router.env` when it does not already exist.
6. Generates a random router API key.
7. Installs and enables `model-router.service`.
8. Binds the router to the machine's Tailscale IPv4 address.

## 5. Inspect the generated configuration

```bash
sudo sed -n '1,120p' /etc/tailscale-ai-router.env
sudo sed -n '1,240p' /opt/tailscale-ai-guide/config/models.yaml
```

The environment file is root-owned and readable by the `ai-router` service group. Do not commit it.

Retrieve the generated API key only when configuring an authorized client:

```bash
sudo grep '^ROUTER_API_KEY=' /etc/tailscale-ai-router.env
```

## 6. Check the service

```bash
sudo systemctl status model-router.service --no-pager
sudo journalctl -u model-router.service -n 100 --no-pager
sudo journalctl -u model-router.service -f
```

Confirm the listener:

```bash
TAILSCALE_IP="$(tailscale ip -4 | head -n 1)"
sudo ss -lntp | grep ':18180'
curl -fsS "http://${TAILSCALE_IP}:18180/health" \
  -H "Authorization: Bearer <ROUTER_API_KEY>"
```

The health endpoint returns:

- `healthy` when every configured backend is available.
- `degraded` when at least one backend is available.
- HTTP `503` with `unavailable` when all backends are unavailable.

## 7. Update the deployed service

After pulling and validating a repository update:

```bash
make validate
sudo bash scripts/linux/install-model-router-service.sh
```

The installer preserves an existing `/etc/tailscale-ai-router.env`, refreshes the installed application files, updates dependencies, and restarts the service.

## 8. Uninstall

```bash
sudo systemctl disable --now model-router.service
sudo rm -f /etc/systemd/system/model-router.service
sudo systemctl daemon-reload
sudo rm -rf /opt/tailscale-ai-guide
sudo rm -f /etc/tailscale-ai-router.env
sudo userdel ai-router
```
