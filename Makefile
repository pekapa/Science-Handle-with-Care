PYTHON ?= python3

.PHONY: test lint format test-engine package
test:
	$(PYTHON) scripts/test.py

lint:
	ruff check scripts tests
	ruff format --check scripts tests
	luacheck mod tests
	stylua --check mod tests

format:
	ruff check --fix scripts tests
	ruff format scripts tests
	stylua mod tests

test-engine:
	$(PYTHON) scripts/test.py --suite engine

package:
	$(PYTHON) scripts/package.py
