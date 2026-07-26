# Linux Setup Guide

This guide is for Ubuntu and Debian compute nodes. It covers installation, naming, authentication, SSH, service binding, firewall controls, and verification.

## 1. Prepare the operating system

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates jq openssh-server ufw
sudo systemctl enable --now ssh
```

Check the current hostname:

```bash
hostnamectl
```

Set a clear hostname before joining the tailnet:

```bash
sudo hostnamectl set-hostname axonvertex-01
```

Log out and back in if the shell prompt does not update.

## 2. Install Tailscale

Official automated installation method:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Confirm the service:

```bash
sudo systemctl enable --now tailscaled
systemctl status tailscaled --no-pager
```

## 3. Authenticate interactively

```bash
sudo tailscale up
```

Open the printed URL and authenticate with the identity that belongs to the intended tailnet.

Verify:

```bash
tailscale status
tailscale ip -4
```

## 4. Provision a shared server with a tag

Define the tag in the policy first. Then use an auth key generated for that tag.

```bash
read -rsp 'Tailscale auth key: ' TS_AUTHKEY
echo

sudo tailscale up \
  --auth-key="$TS_AUTHKEY" \
  --advertise-tags=tag:gpu-model-server \
  --hostname=axonvertex-01

unset TS_AUTHKEY
```

Do not reuse the example tag blindly. Match the server's actual role.

## 5. Enable Tailscale SSH on the Linux destination

```bash
sudo tailscale set --ssh
```

Confirm the setting:

```bash
tailscale status
```

Tailscale SSH requires both:

- A network grant that permits the source to reach the destination.
- An SSH policy rule that permits the source identity, destination, and local username.

The policy example is in:

```text
config/tailnet-policy.example.hujson
```

## 6. Test SSH before changing firewall rules

From a second tailnet device:

```bash
ssh ubuntu@axonvertex-01
```

Or use the stable Tailscale IP:

```bash
ssh ubuntu@100.82.103.57
```

Keep the original console or cloud-provider session open during testing.

## 7. Restrict the firewall to Tailscale

Inspect current rules:

```bash
sudo ufw status verbose
```

Set safe defaults:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Allow traffic arriving through the Tailscale interface:

```bash
sudo ufw allow in on tailscale0
```

Optional: allow the default Tailscale UDP port to improve direct peer-to-peer connectivity:

```bash
sudo ufw allow 41641/udp
```

Enable and reload:

```bash
sudo ufw enable
sudo ufw reload
sudo ufw status verbose
```

Only remove public SSH access after an SSH session over Tailscale has succeeded:

```bash
sudo ufw delete 22/tcp
```

If the machine is in a cloud provider, also remove or restrict public port `22` in the provider firewall or security group.

## 8. Bind model APIs safely

### Preferred method: bind to the Tailscale IP

```bash
TS_IP="$(tailscale ip -4)"
echo "$TS_IP"
```

Use the address in the model server command:

```bash
python3 model_server.py \
  --host "$TS_IP" \
  --port 18181
```

This avoids listening on every network interface.

### Alternative: bind to all interfaces and rely on firewall plus grants

```bash
python3 model_server.py \
  --host 0.0.0.0 \
  --port 18181
```

This is acceptable only when:

- Public firewall rules do not expose the port.
- UFW or equivalent restricts inbound access.
- Tailscale grants restrict which identities can reach the port.
- The model service or gateway also uses application authentication where required.

## 9. Configure Ollama for tailnet access

Use the included script:

```bash
sudo bash scripts/linux/configure-ollama-tailnet.sh
```

It configures Ollama to listen on `0.0.0.0:11434`. The script does not open a public firewall port. Access must remain controlled through `tailscale0` and the tailnet policy.

Verify locally:

```bash
curl -fsS http://127.0.0.1:11434/api/tags | jq
```

Verify over Tailscale from another permitted node:

```bash
curl -fsS http://axonvertex-personal-01:11434/api/tags | jq
```

## 10. Start a model service after Tailscale is online

For systemd services that require the tailnet, add ordering dependencies:

```ini
[Unit]
After=network-online.target tailscale-online.target
Wants=network-online.target tailscale-online.target
```

Check that `tailscale-online.target` exists:

```bash
systemctl list-unit-files | grep tailscale-online
```

## 11. GPU node verification

```bash
nvidia-smi
curl -fsS http://127.0.0.1:18181/v1/models | jq
curl -fsS http://"$(tailscale ip -4)":18181/v1/models | jq
```

From another tailnet node:

```bash
curl -fsS http://axonvertex-01:18181/v1/models | jq
```

## 12. Useful Linux commands

```bash
sudo systemctl status tailscaled --no-pager
sudo journalctl -u tailscaled -n 200 --no-pager
tailscale status
tailscale status --json | jq
tailscale ip -4
tailscale ping axonvertex-personal-01
tailscale netcheck
tailscale dns status
ip address show tailscale0
ss -lntup
sudo ufw status numbered
```

## 13. Upgrade

On supported Ubuntu or Debian versions:

```bash
sudo tailscale update
```

Or use the distribution package manager:

```bash
sudo apt-get update
sudo apt-get install --only-upgrade tailscale
```

Recheck SSH and model endpoints after an upgrade.

## 14. Linux completion checklist

- [ ] Hostname is clear and unique.
- [ ] `tailscaled` is enabled.
- [ ] Machine appears in the intended tailnet.
- [ ] MagicDNS name resolves.
- [ ] `tailscale ping` succeeds.
- [ ] SSH over Tailscale succeeds.
- [ ] Public SSH is removed or tightly restricted.
- [ ] Model API is reachable only through intended interfaces.
- [ ] Tailnet grants permit only required ports.
- [ ] Model health endpoint succeeds from the gateway.
