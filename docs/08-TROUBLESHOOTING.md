# Troubleshooting

## 1. Use the layered diagnostic method

Test in this order:

```text
1. Tailscale client running
2. Device authenticated in correct tailnet
3. Peer visible
4. Peer reachable by Tailscale ping
5. DNS name resolves
6. TCP port reachable
7. Application health endpoint works
8. Model request succeeds
9. Router policy selects the intended backend
```

## 2. Client status

```bash
tailscale version
tailscale status
tailscale ip -4
tailscale netcheck
```

Linux service:

```bash
sudo systemctl status tailscaled --no-pager
sudo journalctl -u tailscaled -n 200 --no-pager
```

Windows PowerShell:

```powershell
Get-Service Tailscale
tailscale status
```

## 3. Peer not visible

Check:

- Same tailnet identity or valid invite.
- Device authorization in admin console.
- Device not expired.
- Client connected rather than paused or logged out.
- Duplicate WSL and Windows nodes.
- Correct hostname.

## 4. `tailscale ping` fails

```bash
tailscale ping axonvertex-01
tailscale ping 100.82.103.57
```

Check access policy and client status. Generate a bug marker when needed:

```bash
tailscale bugreport
```

## 5. Direct versus relay

```bash
tailscale status
```

An active peer can show:

```text
direct <address>
relay <region>
```

Relay is functional. For better throughput, check NAT behavior and allow the Tailscale UDP listener when appropriate:

```bash
sudo ufw allow 41641/udp
```

Confirm the actual listening port before creating fixed firewall rules in customized deployments.

## 6. MagicDNS failure

Test the IP first:

```bash
ping -c 2 100.82.103.57
```

Then test the name:

```bash
getent hosts axonvertex-01
ping -c 2 axonvertex-01
tailscale dns status
```

macOS:

```bash
dscacheutil -q host -a name axonvertex-01
scutil --dns
```

WSL:

```bash
cat /etc/resolv.conf
getent hosts axonvertex-01
nslookup axonvertex-01
```

## 7. SSH fails but ping works

Check TCP port:

```bash
nc -vz axonvertex-01 22
```

Check server:

```bash
sudo systemctl status ssh --no-pager
sudo ss -lntp | grep ':22'
```

Check Tailscale SSH:

```bash
tailscale status
sudo tailscale set --ssh
```

Check both network grant and `ssh` rule. Use verbose client output:

```bash
ssh -vvv ubuntu@axonvertex-01
```

## 8. Model port fails

From the model host:

```bash
ss -lntp | grep -E ':11434|:18180|:18181|:18182'
curl -v http://127.0.0.1:18181/v1/models
```

Using the host Tailscale IP:

```bash
curl -v http://"$(tailscale ip -4)":18181/v1/models
```

From the gateway:

```bash
nc -vz axonvertex-01 18181
curl -v http://axonvertex-01:18181/v1/models
```

Interpretation:

```text
Local loopback fails
  model service issue

Loopback works, Tailscale IP fails locally
  listener binding or host firewall issue

Tailscale IP works locally, remote TCP fails
  Tailscale grant or remote firewall issue

Remote TCP works, health endpoint fails
  application path, authentication, or model readiness issue
```

## 9. Router returns no healthy backend

```bash
curl -sS http://ai-gateway:18180/health \
  -H "Authorization: Bearer $ROUTER_API_KEY" | jq
```

Check:

- Backend hostname.
- Port.
- Provider type.
- Health path.
- Model name.
- Tailscale grant from gateway tag to model tag.
- Model process and logs.
- Router timeout.

## 10. Windows and WSL conflict

Symptoms can include failed encrypted traffic, confusing duplicate nodes, or inconsistent DNS.

Check whether both clients are active:

PowerShell:

```powershell
Get-Service Tailscale
tailscale status
```

WSL:

```bash
systemctl status tailscaled --no-pager || true
tailscale status || true
```

Choose one active location. For the normal operator mode, keep Tailscale on Windows and stop it inside WSL.

## 11. Firewall inspection

Linux:

```bash
sudo ufw status numbered
sudo nft list ruleset
sudo iptables-save
```

Cloud:

- Check security groups.
- Check network ACLs.
- Check provider firewall rules.
- Confirm model ports are not publicly exposed.

## 12. Capture a diagnostic bundle

```bash
mkdir -p diagnostics

tailscale version > diagnostics/tailscale-version.txt
tailscale status > diagnostics/tailscale-status.txt
tailscale status --json > diagnostics/tailscale-status.json
tailscale netcheck > diagnostics/tailscale-netcheck.txt 2>&1
ss -lntup > diagnostics/listeners.txt 2>&1
sudo ufw status verbose > diagnostics/ufw.txt 2>&1 || true
```

Review and remove identities, IPs, logs, tokens, and sensitive service details before sharing the bundle publicly.
