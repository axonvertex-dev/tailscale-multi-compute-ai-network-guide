# Windows and WSL 2 Setup Guide

Windows users perform development and administration from WSL. There are two valid operating modes. Choose one and do not run Tailscale simultaneously on both the Windows host and inside WSL 2.

## 1. Choose the operating mode

### Mode A: Windows is the Tailscale node, WSL is the terminal

Use this for most operators.

```text
Windows host
  Tailscale client and tailnet identity

WSL 2
  ssh, curl, Git, Python, Docker CLI, model API clients
```

Advantages:

- Matches Tailscale's recommended approach for most WSL users.
- One identity for the Windows machine.
- WSL can call remote tailnet services through the Windows network path.
- No nested Tailscale tunnel.

### Mode B: WSL itself is a compute node

Use this only when WSL must host a model API as its own tailnet machine.

```text
Windows host
  Tailscale disconnected or not running

WSL 2
  tailscaled, unique MagicDNS name, SSH server, model API
```

This is an advanced configuration. Do not run the Windows Tailscale client at the same time.

## 2. Confirm WSL 2

Open PowerShell:

```powershell
wsl -l -v
```

The distribution must show version `2`.

Install WSL when needed:

```powershell
wsl --install
```

Restart Windows if requested.

## 3. Mode A: Install Tailscale on Windows

1. Download the official Windows installer.
2. Run the installer.
3. Open the Tailscale system tray menu.
4. Select **Log in**.
5. Authenticate with the intended tailnet identity.

Verify in PowerShell:

```powershell
tailscale status
tailscale ip -4
tailscale ping axonvertex-01
```

If `tailscale` is not found in PowerShell:

```powershell
& "$env:ProgramFiles\Tailscale\tailscale.exe" status
```

## 4. Mode A: Use WSL as the working terminal

Open WSL:

```powershell
wsl.exe
```

Install client utilities:

```bash
sudo apt-get update
sudo apt-get install -y openssh-client curl jq dnsutils netcat-openbsd
```

Test a remote Tailscale IP:

```bash
ping -c 2 100.82.103.57
nc -vz 100.82.103.57 22
ssh ubuntu@100.82.103.57
```

Test MagicDNS:

```bash
getent hosts axonvertex-01
ssh ubuntu@axonvertex-01
```

Test model APIs:

```bash
curl -fsS http://axonvertex-01:18181/v1/models | jq
curl -fsS http://axonvertex-personal-01:11434/api/tags | jq
```

If IP access works but MagicDNS does not, continue using the stable Tailscale IP while troubleshooting WSL DNS.

## 5. Mode A limitation for hosting a service inside WSL

A model server listening inside WSL is not automatically a separate tailnet node when only the Windows host runs Tailscale. Windows and WSL networking modes vary by Windows and WSL version.

Do not assume that this command makes a WSL service reachable from the tailnet:

```bash
python3 server.py --host 0.0.0.0 --port 18181
```

For a reliable service-node design, use Mode B or host the service natively on Windows with an explicitly controlled listener.

## 6. Mode B: Enable systemd in WSL

Inside WSL:

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
```

From PowerShell:

```powershell
wsl --shutdown
```

Open WSL again and confirm:

```bash
systemctl is-system-running
```

## 7. Mode B: Stop Tailscale on Windows

Disconnect or quit the Windows Tailscale client before activating Tailscale inside WSL.

PowerShell administrative option:

```powershell
Stop-Service Tailscale
```

Confirm that the Windows client is not connected.

## 8. Mode B: Install Tailscale inside WSL

Inside WSL:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up --hostname=windows-wsl-ai-node
```

Open the displayed authentication URL.

Verify:

```bash
tailscale status
tailscale ip -4
tailscale netcheck
```

The WSL node might initially have a duplicate or similar name. Rename it clearly in the admin console.

## 9. Mode B: Enable SSH in WSL

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
sudo tailscale set --ssh
```

Test from another tailnet machine:

```bash
ssh <wsl-user>@windows-wsl-ai-node
```

Apply a tailnet network grant and SSH rule before relying on Tailscale SSH.

## 10. Mode B: Host a model API in WSL

Bind to the WSL Tailscale address:

```bash
TS_IP="$(tailscale ip -4)"
python3 model_server.py --host "$TS_IP" --port 18181
```

Verify locally:

```bash
curl -fsS http://"$TS_IP":18181/v1/models
```

Verify from the gateway:

```bash
curl -fsS http://windows-wsl-ai-node:18181/v1/models
```

## 11. Return from Mode B to Mode A

Inside WSL:

```bash
sudo tailscale down
sudo systemctl disable --now tailscaled
```

PowerShell as administrator:

```powershell
Start-Service Tailscale
```

Reconnect the Windows client and verify:

```powershell
tailscale status
```

## 12. WSL DNS troubleshooting

Check resolver configuration:

```bash
cat /etc/resolv.conf
getent hosts axonvertex-01
nslookup axonvertex-01
```

Test the Tailscale IP directly:

```bash
curl -v http://100.82.103.57:18181/v1/models
```

Interpretation:

```text
IP works, name fails
  DNS or MagicDNS forwarding issue

IP and name both fail
  network policy, service listener, firewall, or Tailscale path issue

TCP connects, API fails
  model service or application authentication issue
```

## 13. Windows and WSL completion checklist

- [ ] WSL distribution is version 2.
- [ ] Exactly one Tailscale client is active: Windows or WSL, not both.
- [ ] WSL can SSH to the Linux nodes.
- [ ] WSL can call the required model endpoints.
- [ ] MagicDNS works, or stable Tailscale IPs are documented as fallback.
- [ ] A WSL-hosted service uses Mode B and a unique node identity.
- [ ] Windows Defender Firewall is not exposing model ports publicly.
