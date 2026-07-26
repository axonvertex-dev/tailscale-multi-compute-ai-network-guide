# Security Hardening

## 1. Security layers

Use multiple controls together:

```text
Identity provider
  authenticates users

Tailscale device identity
  authenticates nodes

Tailscale grants
  authorize network paths and ports

SSH policy
  authorizes SSH identities and local users

Host firewall
  prevents unintended interface exposure

Application authentication
  protects gateway and model APIs

AI policy layer
  controls data, tools, models, and actions
```

Tailscale encryption is not a reason to omit application authentication from a shared or multi-user AI service.

## 2. Default-deny network policy

Start from narrow grants rather than an allow-all rule.

Permit:

- Users to gateway port `18180`.
- Gateway to required model ports.
- Administrators to SSH and health endpoints.
- Monitoring system to metrics endpoints.

Deny by omission:

- User-to-user device access.
- Model-node access to personal laptops.
- Direct user access to raw model APIs.
- Database ports from arbitrary nodes.

## 3. Separate users and services

Use:

```text
User identity
  laptops and interactive endpoints

Tag identity
  shared servers and service nodes
```

Do not tag a personal laptop only to make its name easier to target. Applying a tag changes the device identity model.

## 4. Auth-key handling

- Prefer one-off keys.
- Set short expiry.
- Restrict tags.
- Store secrets in a secret manager or protected provisioning mechanism.
- Do not place keys in shell history.
- Do not commit keys to Git.
- Do not include keys in cloud-init output or instance logs.
- Revoke exposed keys immediately.

## 5. SSH controls

- Use explicit local usernames.
- Use `check` mode for high-risk systems.
- Use a shorter check period for root.
- Prefer sudo escalation over direct root login.
- Keep an emergency console path for cloud nodes.
- Remove public port `22` after Tailscale access is verified.
- Review SSH access whenever a group member changes.

## 6. Host firewall

Ubuntu baseline:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0
sudo ufw allow 41641/udp
sudo ufw enable
sudo ufw status verbose
```

Do not add public rules for `11434`, `18180`, `18181`, or `18182` unless the service is intentionally public and separately hardened.

## 7. Service listeners

Preferred:

```bash
--host "$(tailscale ip -4)"
```

Fallback:

```bash
--host 0.0.0.0
```

The fallback requires strict host and cloud firewalls.

Inspect listeners:

```bash
ss -lntup
sudo lsof -nP -iTCP -sTCP:LISTEN
```

## 8. Gateway API authentication

Set a long random secret:

```bash
export ROUTER_API_KEY="$(openssl rand -hex 32)"
```

Require:

```http
Authorization: Bearer <secret>
```

For a team or production deployment, replace a shared bearer secret with workload identity, short-lived credentials, or a proper authentication proxy.

## 9. Model and data policy

The router should evaluate:

- Data classification.
- Model approval status.
- Node jurisdiction and ownership.
- Whether prompts may leave a specific machine.
- Whether logs may retain request content.
- Whether tool execution is allowed.
- Whether human approval is required.

A network path being permitted does not mean every dataset is permitted on every model node.

## 10. Logging

Log:

- Identity.
- Destination service.
- Routing decision.
- Model identifier.
- Timing and outcome.
- Policy decision.

Avoid logging:

- Auth keys.
- API keys.
- SSH private keys.
- Raw credentials in prompts.
- Full sensitive records without approved retention.

## 11. Device lifecycle

When retiring a node:

1. Stop model and gateway services.
2. Remove the device from routing configuration.
3. Revoke application credentials.
4. Remove or expire the Tailscale device.
5. Remove the node from monitoring.
6. Delete stale DNS references and deployment records.
7. Securely erase local model caches and sensitive logs as required.

## 12. Incident response

For a suspected compromised node:

1. Remove or disable it in the Tailscale admin console.
2. Revoke related auth keys and API credentials.
3. Remove it from router profiles.
4. Preserve required logs and forensic evidence.
5. Check policy and configuration audit history.
6. Review peer connections and model request logs.
7. Rebuild rather than trusting an uncertain host state.
