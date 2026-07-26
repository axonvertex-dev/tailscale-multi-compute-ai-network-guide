.PHONY: install run health verify test-endpoints lint

install:
	python3 -m venv .venv
	. .venv/bin/activate && pip install -r router/requirements.txt

run:
	. .venv/bin/activate && uvicorn router.model_router:app --host 0.0.0.0 --port 18180

health:
	curl -fsS http://127.0.0.1:18180/health -H "Authorization: Bearer $$ROUTER_API_KEY"

verify:
	bash scripts/verify-tailnet.sh

test-endpoints:
	bash scripts/test-model-endpoints.sh

lint:
	python3 -m py_compile router/model_router.py
