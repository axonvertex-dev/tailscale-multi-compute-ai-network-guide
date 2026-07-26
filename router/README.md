# Reference Model Router

The router provides one OpenAI-style endpoint for multiple model servers reachable through Tailscale.

## Features

- Static routing profiles.
- Capability filtering.
- Preferred-backend testing.
- Fallback on network errors, timeouts, and `5xx` responses.
- OpenAI-compatible backend forwarding.
- Ollama `/api/chat` conversion for non-streaming requests.
- Backend health reporting.
- Bearer-token authentication required by default.
- Response headers identifying the selected backend.

## Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r router/requirements.txt

cp config/models.example.yaml config/models.yaml
export MODEL_ROUTER_CONFIG="$PWD/config/models.yaml"
export ROUTER_API_KEY="$(openssl rand -hex 32)"
export MODEL_ROUTER_HOST="$(tailscale ip -4 | head -n 1)"

make run
```

The router fails startup when `ROUTER_API_KEY` is missing. Authentication can be disabled only by explicitly setting `ALLOW_INSECURE_NO_AUTH=true`, which is intended solely for an isolated development environment.

For direct Uvicorn startup:

```bash
uvicorn router.model_router:app \
  --host "$(tailscale ip -4 | head -n 1)" \
  --port 18180
```

## Health

```bash
curl -sS "http://$(tailscale ip -4 | head -n 1):18180/health" \
  -H "Authorization: Bearer $ROUTER_API_KEY" | jq
```

## Request

```bash
curl -sS "http://$(tailscale ip -4 | head -n 1):18180/v1/chat/completions" \
  -H "Authorization: Bearer $ROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "routing": {
      "profile": "security",
      "required_capabilities": ["security"]
    },
    "messages": [
      {"role": "user", "content": "Review this log."}
    ],
    "stream": false
  }' | jq
```

Inspect these response headers:

```text
x-model-backend
x-routing-profile
x-request-id
```

## Limitations

- Streaming is not implemented and `stream: true` is rejected for every backend.
- No queue-aware or GPU-metric-aware scoring.
- No persistent audit database.
- No per-user identity mapping beyond one bearer secret.
- No prompt redaction or data policy engine.
- No automatic model discovery.

Use this as an instructional baseline, then place it behind the organization's authentication, policy, audit, and observability controls.

## Linux systemd installation

```bash
cp config/models.example.yaml config/models.yaml
# Edit config/models.yaml for the actual model servers.
sudo bash scripts/linux/install-model-router-service.sh
```

The installer creates the service account, virtual environment, root-protected environment file, systemd unit, and a Tailscale-only listener.
