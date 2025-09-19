.PHONY: render test clean pytest venv

VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest

$(PYTEST): requirements-dev.txt
	python3 -m venv $(VENV)
	$(PYTHON) -m pip install --upgrade pip
	$(PIP) install -r requirements-dev.txt

venv: $(PYTEST)

render: $(PYTEST)
	$(PYTHON) render.py --output goose_egg.sh

# Ensure rendered script matches legacy reference
test: render $(PYTEST)
	./tests/test_render_matches_final.sh
	$(PYTEST)

pytest: $(PYTEST)
	$(PYTEST)

clean:
	rm -f goose_egg.sh
	rm -rf $(VENV)
