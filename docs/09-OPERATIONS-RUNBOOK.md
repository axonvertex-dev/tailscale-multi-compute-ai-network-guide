# Operations Runbook

## 1. Daily readiness check

From the gateway or operator workstation:

```bash
tailscale status
tailscale ping axonvertex-01
tailscale ping axonvertex-personal-01

curl -fsS http://axonvertex-01:18181/v1/models
curl -fsS http://axonvertex-personal-01:11434/api/tags
curl -fsS http://rentorzos-macbook-pro-2:18180/health \
  -H "Authorization: Bearer $ROUTER_API_KEY"
```

Run the included scripts:

```bash
bash scripts/verify-tailnet.sh
bash scripts/test-model-endpoints.sh
```

## 2. Start order

Recommended sequence:

```text
1. Network and operating system
2. tailscaled
3. GPU driver or accelerator runtime
4. model runtime
5. model server
6. model router
7. policy engine or application gateway
8. monitoring and dashboards
9. client applications
```

## 3. Stop order

```text
1. Stop accepting new client requests
2. Drain or complete active requests
3. Stop model router
4. Stop model servers
5. Stop monitoring exporters if required
6. Disconnect Tailscale only when the node is being removed or serviced
```

## 4. Add a new compute node

1. Assign a unique hostname.
2. Install Tailscale.
3. Define the required tag in policy.
4. Provision with interactive login or a controlled auth key.
5. Verify `tailscale status` and `tailscale ping`.
6. Configure SSH.
7. Apply host and cloud firewall restrictions.
8. Install the model runtime.
9. Bind the service to the Tailscale IP.
10. Add the endpoint to `models.yaml`.
11. Add it to one routing profile at low priority.
12. Test health and inference.
13. Promote its routing priority only after observation.

## 5. Remove a compute node

1. Remove it from routing profiles.
2. Confirm no live requests depend on it.
3. Stop model services.
4. Revoke its application credentials.
5. Remove or expire the Tailscale machine.
6. Remove monitoring targets.
7. Remove its tags and policy exceptions.
8. Erase sensitive caches and logs as required.

## 6. Change a model

1. Record the current model identifier and checksum.
2. Download the new model through the approved process.
3. Start it on a non-production port or node.
4. Run health checks.
5. Run functional and safety evaluation.
6. Add it as a lower-priority candidate.
7. Send controlled traffic.
8. Promote after validation.
9. Retain rollback instructions.

## 7. Key and credential rotation

Rotate:

- Router API keys.
- Model service API keys.
- Provisioning auth keys.
- CI credentials.
- SSH keys when using traditional OpenSSH.

A Tailscale auth key expiring does not automatically remove devices previously registered with it. Review device and node-key expiry separately.

## 8. Policy change procedure

1. Edit the version-controlled template.
2. Replace template identities in the controlled environment.
3. Run policy tests.
4. Review the diff.
5. Save through the admin console or API.
6. Test one low-risk path.
7. Test SSH.
8. Test gateway-to-model access.
9. Confirm denied paths remain denied.
10. Record the change.

## 9. Backup and recovery

Keep protected copies of:

- Tailnet policy template.
- Model-router configuration.
- Service unit files.
- Model manifests and checksums.
- Environment-variable names, not secret values.
- Deployment scripts.
- Node inventory.
- Recovery console instructions.

Do not back up live secrets into the Git repository.

## 10. Minimum node inventory

```text
Hostname:
Tailscale IP:
MagicDNS name:
Operating system:
Owner:
Identity type: user or tag
Tags:
Local SSH user:
Compute class:
Model runtime:
Models:
API ports:
Health path:
Routing profiles:
Public firewall state:
Key-expiry state:
Last verified date:
```

## 11. Performance review

For slow inference, separate model performance from network performance:

```text
Model startup time
Prompt processing speed
Token generation speed
GPU memory pressure
Queue time
Tailscale direct or relay path
Round-trip latency
Client rendering or streaming delay
```

Commands:

```bash
tailscale status
tailscale ping axonvertex-01
nvidia-smi
curl -w '\nconnect=%{time_connect} starttransfer=%{time_starttransfer} total=%{time_total}\n' \
  http://axonvertex-01:18181/v1/models
```

## 12. Emergency rollback

If a policy change blocks access:

- Use the Tailscale admin console to restore the last working policy.
- Use the cloud provider console or local console if SSH is unavailable.
- Do not disable the only recovery path before testing the replacement.

If the router fails:

- Remove it from client DNS or service configuration.
- Temporarily point an administrator client to one approved backend.
- Restore the last known working `models.yaml` and router version.
