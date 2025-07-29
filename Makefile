# GoSQL Development Makefile

.PHONY: help install install-dev test test-all lint format clean build publish docs benchmark

# Default target
help:
	@echo "GoSQL Development Commands:"
	@echo ""
	@echo "  install      Install GoSQL in development mode"
	@echo "  install-dev  Install with development dependencies"
	@echo "  test         Run unit tests"
	@echo "  test-all     Run all tests including integration"
	@echo "  lint         Run code linting"
	@echo "  format       Format code with black and isort"
	@echo "  clean        Clean build artifacts"
	@echo "  build        Build package"
	@echo "  publish      Publish to PyPI"
	@echo "  docs         Build documentation"
	@echo "  benchmark    Run performance benchmarks"
	@echo ""

# Installation
install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"
	pre-commit install

# Testing
test:
	pytest tests/ -v

test-all:
	pytest tests/ -v --cov=gosql --cov-report=html
	tox

test-integration:
	pytest tests/ -v -m integration

# Code quality
lint:
	flake8 gosql tests
	mypy gosql
	bandit -r gosql

format:
	black gosql tests
	isort gosql tests

format-check:
	black --check gosql tests
	isort --check-only gosql tests

# Build and publish
clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf .tox/
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

build: clean
	python -m build

publish-test: build
	twine upload --repository testpypi dist/*

publish: build
	twine upload dist/*

# Documentation
docs:
	cd docs && make html

docs-clean:
	cd docs && make clean

# Benchmarks
benchmark:
	python -m gosql.benchmarks.benchmark

benchmark-mysql:
	python -m gosql.benchmarks.benchmark --database mysql

benchmark-postgresql:
	python -m gosql.benchmarks.benchmark --database postgresql

benchmark-mssql:
	python -m gosql.benchmarks.benchmark --database mssql

# Development
dev-setup: install-dev
	@echo "Development environment setup complete!"
	@echo "Run 'make test' to verify installation"

# Docker
docker-build:
	docker build -t gosql:dev .

docker-test:
	docker run --rm gosql:dev make test

# Pre-commit
pre-commit:
	pre-commit run --all-files

# Security
security:
	bandit -r gosql
	safety check

# Performance profiling
profile:
	python -m cProfile -o profile.stats -m gosql.benchmarks.benchmark
	python -c "import pstats; p = pstats.Stats('profile.stats'); p.sort_stats('tottime').print_stats(20)"

# Check dependencies
deps-check:
	pip-audit
	pipenv check

# Release preparation
release-check: clean lint test-all security
	@echo "Release checks passed!"

# All checks
check-all: format-check lint test security
	@echo "All checks passed!"
