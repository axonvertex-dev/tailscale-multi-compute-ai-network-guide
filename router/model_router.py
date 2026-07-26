"""Small health-aware model router for a private Tailscale AI network.

The router accepts an OpenAI-style non-streaming chat request and routes it to
one of the backends declared in a YAML configuration file. It supports
OpenAI-compatible and Ollama chat backends.

This is a reference implementation, not a complete production gateway.
"""

from __future__ import annotations

import logging
import os
import time
import uuid
from pathlib import Path
from typing import Any

import httpx
import yaml
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

CONFIG_PATH = Path(os.getenv("MODEL_ROUTER_CONFIG", "config/models.yaml"))
API_KEY = os.getenv("ROUTER_API_KEY", "")
REQUEST_TIMEOUT = float(os.getenv("ROUTER_REQUEST_TIMEOUT_SECONDS", "120"))
HEALTH_TIMEOUT = float(os.getenv("ROUTER_HEALTH_TIMEOUT_SECONDS", "5"))
LOG_LEVEL = os.getenv("ROUTER_LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("model-router")

app = FastAPI(
    title="Tailscale Multi-Compute Model Router",
    version="1.0.0",
)


def load_config() -> dict[str, Any]:
    if not CONFIG_PATH.exists():
        raise RuntimeError(
            f"Router configuration not found: {CONFIG_PATH}. "
            "Copy config/models.example.yaml to config/models.yaml."
        )

    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle) or {}

    if not isinstance(config.get("backends"), dict):
        raise RuntimeError("Configuration requires a 'backends' mapping.")
    if not isinstance(config.get("profiles"), dict):
        raise RuntimeError("Configuration requires a 'profiles' mapping.")

    return config


def require_api_key(request: Request) -> None:
    if not API_KEY:
        return
    supplied = request.headers.get("authorization", "")
    expected = f"Bearer {API_KEY}"
    if supplied != expected:
        raise HTTPException(status_code=401, detail="Invalid or missing bearer token")


def backend_url(backend: dict[str, Any], path: str) -> str:
    return f"{str(backend['base_url']).rstrip('/')}/{path.lstrip('/')}"


def select_candidates(
    config: dict[str, Any],
    profile_name: str,
    preferred_backend: str | None,
    required_capabilities: list[str],
) -> list[dict[str, Any]]:
    profiles = config["profiles"]
    backends = config["backends"]
    profile = profiles.get(profile_name)
    if not profile:
        raise HTTPException(status_code=400, detail=f"Unknown routing profile: {profile_name}")

    candidates = profile.get("candidates", [])
    if not isinstance(candidates, list) or not candidates:
        raise HTTPException(status_code=503, detail=f"Profile has no candidates: {profile_name}")

    selected: list[dict[str, Any]] = []
    for item in candidates:
        backend_name = item.get("backend")
        backend = backends.get(backend_name)
        if not backend:
            logger.error("Profile %s references unknown backend %s", profile_name, backend_name)
            continue

        available = set(backend.get("capabilities", []))
        if not set(required_capabilities).issubset(available):
            continue

        selected.append(
            {
                "backend_name": backend_name,
                "backend": backend,
                "model": item.get("model"),
            }
        )

    if preferred_backend:
        selected.sort(key=lambda item: item["backend_name"] != preferred_backend)

    return selected


async def check_backend(
    client: httpx.AsyncClient,
    name: str,
    backend: dict[str, Any],
) -> dict[str, Any]:
    health_path = backend.get("health_path")
    if not health_path:
        health_path = "/api/tags" if backend.get("provider") == "ollama" else "/v1/models"

    started = time.perf_counter()
    try:
        response = await client.get(
            backend_url(backend, health_path),
            timeout=HEALTH_TIMEOUT,
        )
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        return {
            "backend": name,
            "healthy": response.is_success,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
        }
    except httpx.HTTPError as exc:
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        return {
            "backend": name,
            "healthy": False,
            "error": type(exc).__name__,
            "latency_ms": latency_ms,
        }


async def forward_openai(
    client: httpx.AsyncClient,
    backend: dict[str, Any],
    payload: dict[str, Any],
    model_name: str | None,
) -> httpx.Response:
    outbound = dict(payload)
    if model_name:
        outbound["model"] = model_name
    path = backend.get("chat_path", "/v1/chat/completions")
    return await client.post(
        backend_url(backend, path),
        json=outbound,
        timeout=REQUEST_TIMEOUT,
    )


async def forward_ollama(
    client: httpx.AsyncClient,
    backend: dict[str, Any],
    payload: dict[str, Any],
    model_name: str | None,
) -> JSONResponse:
    if payload.get("stream") is True:
        raise HTTPException(
            status_code=400,
            detail="The reference router supports non-streaming Ollama requests only.",
        )

    outbound: dict[str, Any] = {
        "model": model_name or payload.get("model"),
        "messages": payload.get("messages", []),
        "stream": False,
    }
    if "temperature" in payload:
        outbound["options"] = {"temperature": payload["temperature"]}

    path = backend.get("chat_path", "/api/chat")
    response = await client.post(
        backend_url(backend, path),
        json=outbound,
        timeout=REQUEST_TIMEOUT,
    )

    if not response.is_success:
        return JSONResponse(
            status_code=response.status_code,
            content=_safe_json(response),
        )

    body = response.json()
    message = body.get("message", {})
    usage = {
        "prompt_tokens": body.get("prompt_eval_count", 0),
        "completion_tokens": body.get("eval_count", 0),
        "total_tokens": body.get("prompt_eval_count", 0) + body.get("eval_count", 0),
    }
    converted = {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": outbound["model"],
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": message.get("role", "assistant"),
                    "content": message.get("content", ""),
                },
                "finish_reason": "stop" if body.get("done", True) else None,
            }
        ],
        "usage": usage,
    }
    return JSONResponse(status_code=200, content=converted)


def _safe_json(response: httpx.Response) -> Any:
    try:
        return response.json()
    except ValueError:
        return {"detail": response.text[:4000]}


@app.get("/")
async def root(request: Request) -> dict[str, Any]:
    require_api_key(request)
    config = load_config()
    return {
        "service": "tailscale-multi-compute-model-router",
        "default_profile": config.get("default_profile", "general"),
        "profiles": sorted(config["profiles"].keys()),
    }


@app.get("/health")
async def health(request: Request) -> dict[str, Any]:
    require_api_key(request)
    config = load_config()
    async with httpx.AsyncClient() as client:
        results = [
            await check_backend(client, name, backend)
            for name, backend in config["backends"].items()
        ]

    return {
        "router": "healthy",
        "config": str(CONFIG_PATH),
        "backends": results,
    }


@app.get("/v1/models")
async def models(request: Request) -> dict[str, Any]:
    require_api_key(request)
    config = load_config()
    data = []
    for profile_name, profile in config["profiles"].items():
        data.append(
            {
                "id": profile_name,
                "object": "model",
                "owned_by": "local-tailnet",
                "candidates": profile.get("candidates", []),
            }
        )
    return {"object": "list", "data": data}


@app.post("/v1/chat/completions")
async def chat_completions(request: Request) -> JSONResponse:
    require_api_key(request)
    payload = await request.json()
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Request body must be a JSON object")
    if not isinstance(payload.get("messages"), list):
        raise HTTPException(status_code=400, detail="'messages' must be a list")

    config = load_config()
    routing = payload.pop("routing", {}) or {}
    if not isinstance(routing, dict):
        raise HTTPException(status_code=400, detail="'routing' must be an object")

    profile_name = routing.get("profile") or config.get("default_profile", "general")
    preferred_backend = routing.get("preferred_backend")
    required_capabilities = routing.get("required_capabilities", []) or []
    if not isinstance(required_capabilities, list):
        raise HTTPException(status_code=400, detail="required_capabilities must be a list")

    candidates = select_candidates(
        config=config,
        profile_name=profile_name,
        preferred_backend=preferred_backend,
        required_capabilities=required_capabilities,
    )
    if not candidates:
        raise HTTPException(
            status_code=503,
            detail="No candidate satisfies the routing profile and required capabilities",
        )

    request_id = request.headers.get("x-request-id", uuid.uuid4().hex)
    failures: list[dict[str, Any]] = []

    async with httpx.AsyncClient() as client:
        for candidate in candidates:
            backend_name = candidate["backend_name"]
            backend = candidate["backend"]
            model_name = candidate["model"]
            provider = str(backend.get("provider", "openai")).lower()
            started = time.perf_counter()

            try:
                if provider == "ollama":
                    result = await forward_ollama(client, backend, payload, model_name)
                    status_code = result.status_code
                    if status_code >= 500:
                        failures.append(
                            {"backend": backend_name, "status_code": status_code}
                        )
                        continue
                    result.headers["x-model-backend"] = backend_name
                    result.headers["x-routing-profile"] = profile_name
                    result.headers["x-request-id"] = request_id
                    logger.info(
                        "request_id=%s profile=%s backend=%s status=%s latency_ms=%.2f",
                        request_id,
                        profile_name,
                        backend_name,
                        status_code,
                        (time.perf_counter() - started) * 1000,
                    )
                    return result

                response = await forward_openai(client, backend, payload, model_name)
                if response.status_code >= 500:
                    failures.append(
                        {"backend": backend_name, "status_code": response.status_code}
                    )
                    continue

                result = JSONResponse(
                    status_code=response.status_code,
                    content=_safe_json(response),
                )
                result.headers["x-model-backend"] = backend_name
                result.headers["x-routing-profile"] = profile_name
                result.headers["x-request-id"] = request_id
                logger.info(
                    "request_id=%s profile=%s backend=%s status=%s latency_ms=%.2f",
                    request_id,
                    profile_name,
                    backend_name,
                    response.status_code,
                    (time.perf_counter() - started) * 1000,
                )
                return result

            except HTTPException:
                raise
            except (httpx.TimeoutException, httpx.NetworkError, httpx.RemoteProtocolError) as exc:
                failures.append(
                    {
                        "backend": backend_name,
                        "error": type(exc).__name__,
                    }
                )
                logger.warning(
                    "request_id=%s profile=%s backend=%s error=%s",
                    request_id,
                    profile_name,
                    backend_name,
                    type(exc).__name__,
                )
                continue

    raise HTTPException(
        status_code=503,
        detail={
            "message": "All routing candidates failed",
            "profile": profile_name,
            "request_id": request_id,
            "failures": failures,
        },
    )
