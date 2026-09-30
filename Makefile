.DEFAULT_GOAL := help
.PHONY: help build html serve check test

PORT ?= 8000
PYTHON ?= python3

help:
	@echo 'make build  Build HTML and PDFs, then check the site'
	@echo 'make html   Build HTML using existing PDFs, then check the site'
	@echo 'make serve  Preview at http://localhost:$(PORT) (PORT=8001 to change)'
	@echo 'make check  Check the existing site without rebuilding'
	@echo 'make test   Run site checks and build/preview regression tests'

build:
	./scripts/build.sh

html:
	./scripts/build.sh --html-only

serve:
	$(PYTHON) scripts/serve.py --no-open $(PORT)

check:
	./scripts/check.sh

test: check
	$(PYTHON) -m unittest discover -s tests
