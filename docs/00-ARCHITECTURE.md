# Architecture and Operating Model

## 1. Objective

The objective is to connect multiple compute machines into one private network so that an operator can:

- Reach every permitted machine by a stable Tailscale IP address or MagicDNS name.
- SSH into Linux compute nodes without exposing SSH to the public internet.
- Call private model APIs across Linux, macOS, and WSL-based environments.
- Route each AI request to the machine and model best suited to the workload.
- Apply one centralized access policy to users, servers, ports, and SSH sessions.
- Keep failed or offline nodes from breaking the full AI system.

## 2. Main concepts

### Tailnet

A tailnet is the private Tailscale network created for an identity or organization. Devices join the tailnet after authentication and receive stable addresses from Tailscale's `100.64.0.0/10` address range.

### User identity

A person signs in with an identity provider account. A user-owned MacBook or Windows laptop should normally retain the person's identity.

### Tagged service identity

A shared server should normally use a tag-based identity, such as:

```text
tag:gpu-model-server
tag:edge-model-server
tag:ai-gateway
tag:observability
```

Tags make the machine's permissions depend on its role rather than on whichever person happened to provision it.

### MagicDNS

MagicDNS lets clients use machine names instead of memorizing `100.x.y.z` addresses:

```bash
ssh ubuntu@axonvertex-01
curl http://axonvertex-personal-01:11434/api/tags
```

### Grants

Grants are the preferred modern Tailscale policy syntax for authorizing network traffic. A grant defines:

- Source identity.
- Destination identity.
- Permitted protocol and port.

### Tailscale SSH

Tailscale SSH can manage authentication and authorization for SSH connections to supported destination nodes. It is especially useful for Linux servers. Traditional OpenSSH can also run over the Tailscale network.

## 3. Example topology

```text
                                  TAILSCALE CONTROL PLANE
                              identity, policy, key coordination
                                            |
               ----------------------------------------------------------------
               |                              |                               |
               |                              |                               |
  rentorzos-macbook-pro-2          axonvertex-01              axonvertex-personal-01
  100.76.212.84                    100.82.103.57              100.99.149.21
  macOS                            Linux GPU node             Linux GPU node
  Operator + MLX + gateway         Larger models              Smaller models/fallback
  Router port: 18180               Model port: 18181          Ollama port: 11434
```

Data-plane model traffic flows directly between machines whenever direct peer-to-peer connectivity is available. If direct connectivity cannot be established, Tailscale can use a DERP relay.

## 4. Recommended identity model

### User-owned devices

Use user identity for:

- Developer laptops.
- Personal workstations.
- Phones and tablets.
- A Mac used interactively by one operator.

Do not convert a personal laptop to a tagged identity merely to organize it. Tags are designed for service-based devices and replace the user's identity on that device.

### Shared or unattended servers

Use tags for:

- GPU servers.
- Cloud instances.
- Always-on inference nodes.
- Model gateways.
- Monitoring systems.
- CI runners.

Suggested tags:

```text
tag:ai-gateway
tag:gpu-model-server
tag:edge-model-server
tag:observability
tag:development
tag:production
```

Use composite tags where access depends on multiple characteristics:

```text
tag:production-gpu-model-server
tag:development-edge-model-server
```

## 5. Service ports used in the example

```text
22       SSH
11434    Ollama API
18180    Central model router or AI gateway
18181    Primary OpenAI-compatible model API
18182    Optional secondary OpenAI-compatible model API
3000     Optional dashboard
9090     Optional Prometheus
```

Each service should be reachable only from the identities that need it. Do not use one broad `allow all` rule for convenience in a shared tailnet.

## 6. Model-routing pattern

The central router receives one stable request endpoint:

```text
http://ai-gateway:18180/v1/chat/completions
```

The router then selects a backend:

```text
security workload
  -> axonvertex-01:18181
  -> fallback axonvertex-personal-01:11434

general workload
  -> rentorzos-macbook-pro-2:18181
  -> fallback axonvertex-personal-01:11434

lightweight workload
  -> axonvertex-personal-01:11434
```

Selection can consider:

- Requested profile.
- Model capability.
- GPU memory class.
- Context length.
- Node health.
- Current queue length.
- Privacy policy.
- Cost or power constraints.
- Fallback priority.

Tailscale transports the request securely. The router owns model selection and application-level controls.

## 7. Recommended trust boundaries

```text
User device
  -> may call gateway only

AI gateway
  -> may call model-server ports
  -> may call observability services

Model server
  -> should not initiate arbitrary connections to user devices

Administrator
  -> may SSH to service nodes
  -> may access service health and monitoring ports
```

This pattern reduces the number of clients that can directly call raw model servers.

## 8. Direct versus relay connections

Run:

```bash
tailscale status
tailscale ping axonvertex-01
tailscale netcheck
```

A peer entry can show `direct` or `relay`. Direct is generally preferable for latency and throughput. Relay is functional but may reduce model-streaming performance.

If a firewall allows it, UDP port `41641` can improve the chance of a direct path. Tailscale can still operate through relays when direct connectivity is unavailable.

## 9. Failure model

The router must assume that any compute node can be:

- Offline.
- Sleeping.
- Updating.
- Out of GPU memory.
- Running a different model version.
- Reachable only by relay.
- Healthy at the network layer but unhealthy at the model layer.

Therefore, use both:

```text
Network health: tailscale ping, TCP connection
Application health: /health, /v1/models, /api/tags
```

Do not treat a device appearing in `tailscale status` as proof that its model is ready.
