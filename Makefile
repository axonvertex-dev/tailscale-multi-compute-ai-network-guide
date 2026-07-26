.PHONY: install run health verify test-endpoints test-router lint validate install-service

install:
	python3 -m venv .venv
	. .venv/bin/activate && pip install -r router/requirements.txt

run:
	@set -eu; \
	test -n "$${ROUTER_API_KEY:-}" || { echo "ROUTER_API_KEY is required" >&2; exit 1; }; \
	HOST="$${MODEL_ROUTER_HOST:-$$(tailscale ip -4 | head -n 1)}"; \
	test -n "$$HOST" || { echo "No Tailscale IPv4 address found" >&2; exit 1; }; \
	. .venv/bin/activate; \
	exec uvicorn router.model_router:app --host "$$HOST" --port "$${MODEL_ROUTER_PORT:-18180}"

health:
	@set -eu; \
	test -n "$${ROUTER_API_KEY:-}" || { echo "ROUTER_API_KEY is required" >&2; exit 1; }; \
	HOST="$${MODEL_ROUTER_HOST:-$$(tailscale ip -4 | head -n 1)}"; \
	curl -fsS "http://$$HOST:$${MODEL_ROUTER_PORT:-18180}/health" \
	  -H "Authorization: Bearer $$ROUTER_API_KEY"

verify:
	bash scripts/verify-tailnet.sh

test-endpoints:
	bash scripts/test-model-endpoints.sh

test-router:
	. .venv/bin/activate && python scripts/test-router-behavior.py

lint:
	@test -x .venv/bin/python || { echo "Run make install first" >&2; exit 1; }
	.venv/bin/python -m py_compile router/model_router.py scripts/test-router-behavior.py
	@find scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n

validate: lint test-router
	@.venv/bin/python -c "import pathlib, yaml; [yaml.safe_load(p.read_text()) for p in pathlib.Path('config').glob('*.yaml')]; print('YAML validation passed')"

install-service:
	sudo bash scripts/linux/install-model-router-service.sh
