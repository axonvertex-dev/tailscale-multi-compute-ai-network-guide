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
- Optional bearer-token authentication.
- Response headers identifying the selected backend.

## Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r router/requirements.txt

cp config/models.example.yaml config/models.yaml
export MODEL_ROUTER_CONFIG="$PWD/config/models.yaml"
export ROUTER_API_KEY="$(openssl rand -hex 32)"

uvicorn router.model_router:app --host 0.0.0.0 --port 18180
```

Prefer binding to the Tailscale IP:

```bash
uvicorn router.model_router:app \
  --host "$(tailscale ip -4)" \
  --port 18180
```

## Health

```bash
curl -sS http://127.0.0.1:18180/health \
  -H "Authorization: Bearer $ROUTER_API_KEY" | jq
```

## Request

```bash
curl -sS http://127.0.0.1:18180/v1/chat/completions \
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

- Ollama streaming is not implemented.
- No queue-aware or GPU-metric-aware scoring.
- No persistent audit database.
- No per-user identity mapping beyond one bearer secret.
- No prompt redaction or data policy engine.
- No automatic model discovery.

Use this as an instructional baseline, then place it behind the organization's authentication, policy, audit, and observability controls.
