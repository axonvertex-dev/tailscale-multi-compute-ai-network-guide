# macOS Setup Guide

This guide treats macOS primarily as an operator workstation. It can also host an MLX model server or the central model router.

## 1. Supported installation choice

Use the Tailscale standalone macOS application from Tailscale's package server. Tailscale recommends this variant over the Mac App Store variant for most installations.

Do not install the standalone and App Store variants at the same time.

## 2. Install and authenticate

1. Download the standalone package.
2. Install `Tailscale.app`.
3. Approve the system extension and VPN configuration when macOS requests it.
4. Sign in with the identity that owns or has access to the intended tailnet.
5. Confirm that the Mac appears in the admin console.

Suggested machine name:

```text
rentorzos-macbook-pro-2
```

## 3. Install command-line integration

For the standalone app on macOS Ventura 13 or later:

1. Open the Tailscale app.
2. Open **Settings**.
3. Find **CLI integration**.
4. Select **Show me how**.
5. Select **Install Now**.

This installs:

```text
/usr/local/bin/tailscale
```

Verify:

```bash
which tailscale
tailscale version
tailscale status
```

For the Mac App Store variant, use the bundled path:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale status
```

Optional alias:

```bash
echo 'alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"' >> ~/.zshrc
source ~/.zshrc
```

## 4. Verify the example network

```bash
tailscale status
```

Expected form:

```text
100.76.212.84   rentorzos-macbook-pro-2      krishdasgupta.official@  macOS  -
100.82.103.57   axonvertex-01                krishdasgupta.official@  linux  -
100.99.149.21   axonvertex-personal-01       krishdasgupta.official@  linux  -
```

Check the local address:

```bash
tailscale ip -4
```

Check peers:

```bash
tailscale ping axonvertex-01
tailscale ping axonvertex-personal-01
```

## 5. SSH from the Mac to Linux compute nodes

```bash
ssh ubuntu@axonvertex-01
ssh axonvertex@axonvertex-personal-01
```

Or use Tailscale IP addresses:

```bash
ssh ubuntu@100.82.103.57
ssh axonvertex@100.99.149.21
```

For repeat use, create `~/.ssh/config`:

```sshconfig
Host axonvertex-01
    HostName axonvertex-01
    User ubuntu
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host axonvertex-personal-01
    HostName axonvertex-personal-01
    User axonvertex
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Test:

```bash
ssh axonvertex-01
ssh axonvertex-personal-01
```

## 6. Receive SSH connections on the Mac

The standard macOS GUI variants can act as Tailscale SSH clients but not as Tailscale SSH servers. To reach the Mac, use ordinary macOS Remote Login over the private Tailscale path.

Enable Remote Login:

```bash
sudo systemsetup -setremotelogin on
```

Confirm:

```bash
sudo systemsetup -getremotelogin
sudo lsof -nP -iTCP:22 -sTCP:LISTEN
```

Connect from another tailnet node:

```bash
ssh rentorzo@rentorzos-macbook-pro-2
```

Keep the Tailscale network policy restrictive even though OpenSSH performs its own authentication.

## 7. Host an MLX model service

Bind the service directly to the Mac's Tailscale IP when the server supports an explicit host argument:

```bash
TS_IP="$(tailscale ip -4)"
echo "$TS_IP"

python3 server.py \
  --host "$TS_IP" \
  --port 18181
```

The exact MLX server command depends on the project. The network rule remains the same: listen on the Tailscale IP or use a protected local reverse proxy.

Verify locally:

```bash
curl -fsS http://"$(tailscale ip -4)":18181/v1/models
```

Verify from another permitted machine:

```bash
curl -fsS http://rentorzos-macbook-pro-2:18181/v1/models
```

## 8. Run the central model router on the Mac

```bash
cd tailscale-multi-compute-ai-network-guide
python3 -m venv .venv
source .venv/bin/activate
pip install -r router/requirements.txt

cp config/models.example.yaml config/models.yaml
export MODEL_ROUTER_CONFIG="$PWD/config/models.yaml"
export ROUTER_API_KEY="$(openssl rand -hex 32)"

uvicorn router.model_router:app \
  --host "$(tailscale ip -4)" \
  --port 18180
```

Binding to the Tailscale IP prevents the router from listening on the Mac's Wi-Fi and Ethernet addresses.

Test:

```bash
curl -fsS http://"$(tailscale ip -4)":18180/health \
  -H "Authorization: Bearer $ROUTER_API_KEY"
```

## 9. Prevent sleep during an active model session

For a temporary interactive session:

```bash
caffeinate -dimsu
```

Or run a command under `caffeinate`:

```bash
caffeinate -dimsu uvicorn router.model_router:app \
  --host "$(tailscale ip -4)" \
  --port 18180
```

A sleeping Mac is an unavailable model node. Do not place it first in a production fallback chain unless its power policy is controlled.

## 10. Useful macOS commands

```bash
tailscale status
tailscale status --json | jq
tailscale ip -4
tailscale ping axonvertex-01
tailscale netcheck
tailscale dns status
scutil --dns
networksetup -listallnetworkservices
lsof -nP -iTCP -sTCP:LISTEN
log show --last 15m --predicate 'process contains "Tailscale"'
```

## 11. macOS completion checklist

- [ ] Only one macOS Tailscale variant is installed.
- [ ] CLI integration works.
- [ ] Mac appears with the intended hostname.
- [ ] Linux MagicDNS names resolve.
- [ ] SSH to both Linux nodes succeeds.
- [ ] Any MLX API binds to the Tailscale IP.
- [ ] The model router uses an API key.
- [ ] Sleep behavior is understood.
- [ ] Remote Login is enabled only when needed.
