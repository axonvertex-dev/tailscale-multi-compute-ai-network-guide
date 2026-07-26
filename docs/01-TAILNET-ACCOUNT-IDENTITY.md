# Create the Tailnet, Add Identities, and Register Devices

## 1. Prerequisites

You need:

- An identity provider account supported by Tailscale.
- Administrative control of the machines being connected.
- At least two devices for testing.
- A naming convention for users, servers, and roles.
- A record of which local operating-system usernames are permitted for SSH.

## 2. Create the Tailscale account and tailnet

1. Open the Tailscale website and select **Get Started**.
2. Sign in with the chosen identity provider.
3. Select personal or business use as appropriate.
4. Install Tailscale on the first machine.
5. Authenticate the first machine with the same identity.
6. Open the admin console and confirm that the machine appears.

The first authenticated identity creates the tailnet. Tailscale uses the identity provider for login. You do not create a separate reusable Tailscale password for every machine.

## 3. Choose the primary administrative identity

For this example, the displayed identity is:

```text
krishdasgupta.official@
```

The complete identity in a policy file must match the exact login shown in the Tailscale admin console, for example:

```text
krishdasgupta.official@gmail.com
```

Do not infer or shorten identity strings in the access policy. Copy the exact value from the **Users** page.

## 4. Add another person

Use the **Users** page in the admin console.

For users outside the tailnet's identity domain:

1. Select **Invite external users**.
2. Send an email invite or copy an invite link.
3. The invited person signs in with a supported identity provider.
4. Verify that the person appears in the user list.
5. Add the person to the correct policy group before granting access to compute nodes.

Suggested policy groups:

```text
group:ai-admins
group:ai-operators
group:ai-users
group:security-reviewers
```

## 5. Device naming convention

Use names that identify role and ownership without embedding secrets.

Good examples:

```text
rentorzos-macbook-pro-2
axonvertex-01
axonvertex-personal-01
ai-gateway-01
gpu-prod-01
observability-01
```

Avoid:

```text
ubuntu
server
localhost
my-pc
gpu-with-customer-data
```

Rename devices in the admin console when the operating-system hostname is unclear.

## 6. Enable and retain MagicDNS

MagicDNS is normally enabled by default for newer tailnets. Confirm it on the **DNS** page.

Test from a connected machine:

```bash
tailscale dns status
getent hosts axonvertex-01 2>/dev/null || true
ping -c 2 axonvertex-01
```

On macOS:

```bash
dscacheutil -q host -a name axonvertex-01
ping -c 2 axonvertex-01
```

The stable Tailscale IP remains a useful fallback:

```bash
ping -c 2 100.82.103.57
```

## 7. User authentication versus server provisioning

### Interactive device

Use browser-based login:

```bash
sudo tailscale up
```

This is suitable for a laptop or a server being provisioned manually.

### Unattended service node

Use a one-off or carefully controlled reusable auth key with a server tag.

Example:

```bash
export TS_AUTHKEY='tskey-auth-REPLACE-ME'

sudo tailscale up \
  --auth-key="$TS_AUTHKEY" \
  --advertise-tags=tag:gpu-model-server \
  --hostname=axonvertex-01

unset TS_AUTHKEY
```

Security requirements:

- Prefer a one-off key for one server.
- Set a short key expiry.
- Apply only the required tags.
- Never commit an auth key to Git.
- Never paste a real key into a Markdown guide, shell script, issue, or CI log.
- Revoke the key if it was exposed.
- Prefer an OAuth-based provisioning workflow for mature automation.

## 8. Define tags before using them

Tags must be declared in the tailnet policy file.

```json
{
  "tagOwners": {
    "tag:ai-gateway": ["group:ai-admins"],
    "tag:gpu-model-server": ["group:ai-admins"],
    "tag:edge-model-server": ["group:ai-admins"],
    "tag:observability": ["group:ai-admins"]
  }
}
```

Use tags on service nodes, not on ordinary user-owned laptops.

## 9. Register the three example machines

### Mac

Expected identity:

```text
rentorzos-macbook-pro-2  user-owned macOS device
```

### Primary Linux GPU node

Expected role:

```text
axonvertex-01  tag:gpu-model-server
```

### Secondary Linux node

Expected role:

```text
axonvertex-personal-01  tag:edge-model-server
```

After all machines join:

```bash
tailscale status
```

Expected form:

```text
100.76.212.84   rentorzos-macbook-pro-2      krishdasgupta.official@  macOS  -
100.82.103.57   axonvertex-01                tag:gpu-model-server     linux  -
100.99.149.21   axonvertex-personal-01       tag:edge-model-server    linux  -
```

The identity column can differ depending on whether the device is still user-owned or has been converted to a tagged identity.

## 10. Initial verification checklist

Run on every node:

```bash
tailscale version
tailscale status
tailscale ip -4
tailscale netcheck
```

Run cross-node checks:

```bash
tailscale ping rentorzos-macbook-pro-2
tailscale ping axonvertex-01
tailscale ping axonvertex-personal-01
```

Do not continue to firewall lockdown until at least one complete round of cross-node connectivity tests succeeds.
