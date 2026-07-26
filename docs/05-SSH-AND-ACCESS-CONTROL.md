# SSH and Access Control

## 1. Decide between two SSH patterns

### Tailscale SSH

Use when you want Tailscale to manage SSH identity and authorization centrally.

Destination support in this architecture:

- Linux: supported.
- Standard macOS GUI client: client only, not a Tailscale SSH server.
- WSL: supported when Tailscale runs inside WSL and the WSL node is the destination.

Enable on a Linux destination:

```bash
sudo tailscale set --ssh
```

### Traditional OpenSSH over Tailscale

Use standard SSH keys or passwords, but connect to the Tailscale IP or MagicDNS name.

```bash
ssh ubuntu@axonvertex-01
```

This still benefits from Tailscale's encrypted private path and network grants.

## 2. Policy requirements for Tailscale SSH

A successful Tailscale SSH connection needs two policy layers:

1. A grant that permits network access from the source to the destination.
2. An `ssh` rule that permits the source identity, destination, and local OS username.

Example:

```json
{
  "groups": {
    "group:ai-admins": ["krishdasgupta.official@gmail.com"]
  },
  "tagOwners": {
    "tag:gpu-model-server": ["group:ai-admins"]
  },
  "grants": [
    {
      "src": ["group:ai-admins"],
      "dst": ["tag:gpu-model-server"],
      "ip": ["tcp:22"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "checkPeriod": "12h",
      "src": ["group:ai-admins"],
      "dst": ["tag:gpu-model-server"],
      "users": ["ubuntu"]
    }
  ]
}
```

Use explicit local usernames for shared servers. Avoid `autogroup:nonroot` on a broad tagged destination unless every permitted source should be able to log in as every non-root local account.

## 3. Root access

Keep root access separate and more restrictive:

```json
{
  "action": "check",
  "checkPeriod": "1h",
  "src": ["group:ai-admins"],
  "dst": ["tag:gpu-model-server"],
  "users": ["root"]
}
```

Consider not permitting direct root SSH at all. Prefer:

```bash
ssh ubuntu@axonvertex-01
sudo -i
```

This preserves local sudo auditing.

## 4. Test from each operator platform

### macOS

```bash
ssh ubuntu@axonvertex-01
```

### Linux

```bash
ssh ubuntu@axonvertex-01
```

### WSL

```bash
ssh ubuntu@axonvertex-01
```

If Tailscale SSH does not apply, the same command can still use OpenSSH over the Tailscale path, depending on the destination configuration.

## 5. Lock down public SSH

Perform these steps in order:

1. Keep the existing console or public SSH session open.
2. Install and authenticate Tailscale.
3. Confirm `tailscale ping` from another node.
4. Confirm a second SSH session over the Tailscale IP.
5. Confirm sudo access in the new session.
6. Allow `tailscale0` in the host firewall.
7. Remove public port `22` from the host firewall.
8. Remove public port `22` from the cloud firewall or security group.
9. Re-test after reconnecting.

Ubuntu example:

```bash
sudo ufw allow in on tailscale0
sudo ufw delete 22/tcp
sudo ufw reload
sudo ufw status verbose
```

## 6. SSH client configuration

Example `~/.ssh/config`:

```sshconfig
Host axonvertex-01
    HostName axonvertex-01
    User ubuntu
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 10

Host axonvertex-personal-01
    HostName axonvertex-personal-01
    User axonvertex
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ConnectTimeout 10
```

Do not disable host-key checking globally. Tailscale identity and SSH host-key verification address different parts of the connection.

## 7. File transfer

```bash
scp ./config/models.yaml ubuntu@axonvertex-01:/tmp/models.yaml
rsync -avP ./repo/ ubuntu@axonvertex-01:~/repo/
sftp ubuntu@axonvertex-01
```

Taildrop can also transfer files between supported Tailscale devices, but it is not a replacement for version-controlled deployment.

## 8. Operational SSH commands

```bash
tailscale ping axonvertex-01
nc -vz axonvertex-01 22
ssh -vvv ubuntu@axonvertex-01
sudo journalctl -u tailscaled -n 100 --no-pager
sudo journalctl -u ssh -n 100 --no-pager
```

## 9. Access policy change process

Before saving a policy:

- Replace all sample identities.
- Confirm every tag has an owner.
- Limit source groups.
- Limit destination tags.
- Limit ports.
- Use policy tests.
- Keep an emergency administrative path.
- Review the diff in version control.

Store a redacted or template version in Git. Keep the authoritative policy in the Tailscale admin console or a controlled policy-as-code workflow.
