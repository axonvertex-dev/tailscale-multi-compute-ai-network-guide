#!/usr/bin/env python3
"""Dependency-light behavioral checks for the reference model router."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

CONFIG = """\
backends:
  unavailable-test-backend:
    provider: openai
    base_url: http://127.0.0.1:9
    capabilities: [general]
profiles:
  general:
    candidates:
      - backend: unavailable-test-backend
        model: test-model
default_profile: general
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        config_path = Path(directory) / "models.yaml"
        config_path.write_text(CONFIG, encoding="utf-8")

        os.environ["MODEL_ROUTER_CONFIG"] = str(config_path)
        os.environ["ROUTER_API_KEY"] = "test-secret"
        os.environ["ROUTER_HEALTH_TIMEOUT_SECONDS"] = "0.2"

        from fastapi.testclient import TestClient
        from router.model_router import app

        with TestClient(app) as client:
            response = client.get("/health")
            assert response.status_code == 401, response.text

            headers = {"Authorization": "Bearer test-secret"}
            response = client.get("/health", headers=headers)
            assert response.status_code == 503, response.text
            assert response.json()["router"] == "unavailable", response.text

            response = client.post(
                "/v1/chat/completions",
                headers={**headers, "Content-Type": "application/json"},
                content="{invalid",
            )
            assert response.status_code == 400, response.text

            response = client.post(
                "/v1/chat/completions",
                headers=headers,
                json={"messages": [], "stream": True},
            )
            assert response.status_code == 400, response.text

    print("Router behavioral checks passed.")


if __name__ == "__main__":
    main()
