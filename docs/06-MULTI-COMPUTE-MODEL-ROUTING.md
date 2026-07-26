# Multi-Compute Model Routing

## 1. Problem statement

A Tailscale network can make all compute nodes reachable, but it does not automatically decide:

- Which model should receive a request.
- Which node has enough GPU or unified memory.
- Which backend is healthy.
- Which model is approved for a data classification.
- What to do when a model is unavailable.

Use a central model router or gateway for these decisions.

## 2. Example compute inventory

```text
Node: axonvertex-01
Tailscale IP: 100.82.103.57
MagicDNS: axonvertex-01
Class: primary GPU
Typical API: http://axonvertex-01:18181
Use: security reasoning, code analysis, larger context

Node: axonvertex-personal-01
Tailscale IP: 100.99.149.21
MagicDNS: axonvertex-personal-01
Class: constrained GPU or edge node
Typical API: http://axonvertex-personal-01:11434
Use: lightweight tasks, classifiers, fallback

Node: rentorzos-macbook-pro-2
Tailscale IP: 100.76.212.84
MagicDNS: rentorzos-macbook-pro-2
Class: Apple unified memory / MLX
Typical API: http://rentorzos-macbook-pro-2:18181
Use: MLX inference, multimodal experiments, local development
```

## 3. Recommended flow

```text
Client
  -> http://ai-gateway:18180
  -> authentication
  -> policy and data classification
  -> route selection
  -> model endpoint over Tailscale
  -> response validation
  -> audit and metrics
  -> client
```

Clients should normally call only the gateway. Raw model ports should be reachable only from the gateway and administrators.

## 4. Routing profiles

A routing profile is a logical workload class rather than a physical machine name.

Example profiles:

```text
security
  Primary: larger security model on axonvertex-01
  Fallback: smaller model on axonvertex-personal-01

general
  Primary: MLX model on Mac
  Fallback: general model on axonvertex-personal-01

lightweight
  Primary: small model on axonvertex-personal-01

multimodal
  Primary: Mac MLX/VLM service
  Fallback: GPU VLM service when configured
```

The client sends:

```json
{
  "model": "auto",
  "routing": {
    "profile": "security"
  },
  "messages": [
    {"role": "user", "content": "Review this stack trace."}
  ]
}
```

The physical model name remains in the router configuration, not in every client.

## 5. Configuration

Copy the example:

```bash
cp config/models.example.yaml config/models.yaml
```

Edit:

```yaml
backends:
  gpu-primary:
    provider: openai
    base_url: http://axonvertex-01:18181
    capabilities: [security, reasoning, code]

  gpu-secondary:
    provider: ollama
    base_url: http://axonvertex-personal-01:11434
    capabilities: [general, lightweight, fallback]

  mac-mlx:
    provider: openai
    base_url: http://rentorzos-macbook-pro-2:18181
    capabilities: [general, mlx]
```

Use MagicDNS names for readability. Use Tailscale IPs when DNS reliability is more important than readability in a particular environment.

## 6. Start the included router

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r router/requirements.txt

export MODEL_ROUTER_CONFIG="$PWD/config/models.yaml"
export ROUTER_API_KEY="$(openssl rand -hex 32)"
export ROUTER_REQUEST_TIMEOUT_SECONDS=120

uvicorn router.model_router:app \
  --host 0.0.0.0 \
  --port 18180
```

On a multi-interface machine, prefer the Tailscale IP:

```bash
uvicorn router.model_router:app \
  --host "$(tailscale ip -4)" \
  --port 18180
```

## 7. Check router health

```bash
curl -fsS http://127.0.0.1:18180/health \
  -H "Authorization: Bearer $ROUTER_API_KEY" | jq
```

The response reports router health and backend application health. A backend can be visible in `tailscale status` yet fail its application health check.

## 8. Send a routed request

```bash
curl -sS http://rentorzos-macbook-pro-2:18180/v1/chat/completions \
  -H "Authorization: Bearer $ROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "routing": {
      "profile": "security",
      "required_capabilities": ["security"]
    },
    "messages": [
      {"role": "system", "content": "You are a security reviewer."},
      {"role": "user", "content": "Review this command for risk: curl example | sh"}
    ],
    "stream": false
  }' | jq
```

## 9. Force a preferred backend for testing

```json
"routing": {
  "profile": "security",
  "preferred_backend": "gpu-secondary"
}
```

The router tries the preferred backend first only if it is listed in the selected profile and satisfies the required capabilities.

Do not let ordinary clients supply arbitrary backend URLs.

## 10. Health checks and fallback

Recommended checks:

```text
OpenAI-compatible service
  GET /v1/models

Ollama
  GET /api/tags

Custom model server
  GET /health
```

Fallback rules:

- Retry another candidate for connection errors, timeouts, and `5xx` responses.
- Do not silently fallback on most `4xx` errors because the request itself might be invalid.
- Record which backend answered.
- Return a clear error if every candidate fails.
- Do not retry a request that can produce side effects unless the operation is designed to be idempotent.

## 11. Tailscale access policy for model routing

Recommended communication pattern:

```text
group:ai-users -> tag:ai-gateway tcp:18180
tag:ai-gateway -> tag:gpu-model-server tcp:18181,tcp:11434
tag:ai-gateway -> tag:edge-model-server tcp:18181,tcp:11434
group:ai-admins -> all model nodes tcp:22 and health ports
```

Ordinary users should not need direct access to raw model ports.

## 12. Binding model services

### Bind to Tailscale IP

```bash
HOST="$(tailscale ip -4)"
python3 server.py --host "$HOST" --port 18181
```

### Bind to all interfaces

```bash
python3 server.py --host 0.0.0.0 --port 18181
```

Use the second pattern only with host firewall restrictions, cloud firewall restrictions, Tailscale grants, and application authentication.

## 13. Route by workload and compute capability

Example decision order:

```text
1. Is the data allowed on this node?
2. Does the backend have the required capability?
3. Is the model loaded and healthy?
4. Does the node have enough free memory?
5. Is the queue below the configured threshold?
6. Is a direct path available or is relay latency acceptable?
7. Use the highest-priority remaining candidate.
```

The included router implements static profiles, capability filtering, health-aware fallback, and preferred-backend testing. A production router can add GPU metrics and queue-aware scoring.

## 14. Environment variables for applications

Instead of hard-coding model nodes throughout an application:

```bash
export OPENAI_BASE_URL=http://ai-gateway:18180/v1
export OPENAI_API_KEY="$ROUTER_API_KEY"
export AI_ROUTING_PROFILE=security
```

For a direct administrative test only:

```bash
export PRIMARY_MODEL_URL=http://axonvertex-01:18181
export SECONDARY_MODEL_URL=http://axonvertex-personal-01:11434
export MAC_MLX_URL=http://rentorzos-macbook-pro-2:18181
```

## 15. Observability

Record at least:

- Request ID.
- Selected routing profile.
- Selected backend.
- Model name and version.
- Start time and latency.
- Input and output token counts when available.
- Fallback events.
- Error category.
- Tailscale peer path state when relevant.
- Data classification and policy decision.

Do not log raw prompts containing secrets, credentials, personal data, health information, or customer data unless there is an explicit approved retention policy.
