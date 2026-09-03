.PHONY: setup test lint format synth infer health clean

RUN_ID ?= $(shell date +%Y%m%d_%H%M%S)

setup:
	python3 scripts/setup_env.py

health:
	uv run python scripts/check_health.py

test:
	uv run pytest tests/

lint:
	uv run ruff check src tests scripts

format:
	uv run ruff format src tests scripts

synth:
	uv run python scripts/generate_synth.py --output data/synthetic_edc.csv --n 500

infer:
	@echo "Running infer with run_id: run_$(RUN_ID)"
	uv run python scripts/infer.py --input data/synthetic_edc.csv --output skill_out/anomaly_detection/run_$(RUN_ID)/anomaly_results.jsonl

clean:
	rm -rf .pytest_cache .ruff_cache build dist *.egg-info skill_out/
