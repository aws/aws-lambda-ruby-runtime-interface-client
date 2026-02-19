.PHONY: target
target:
	$(info ${HELP_MESSAGE})
	@exit 0

.PHONY: init
init:
	bundle install

.PHONY: setup-codebuild-agent
setup-codebuild-agent:
	docker build -t codebuild-agent - < test/integration/codebuild-local/Dockerfile.agent

.PHONY: test-smoke
test-smoke: setup-codebuild-agent
	CODEBUILD_IMAGE_TAG=codebuild-agent test/integration/codebuild-local/test_one.sh test/integration/codebuild/buildspec.os.alpine.1.yml alpine 3.16 3.1

.PHONY: test-unit
test-unit:
	ruby test/run_tests.rb unit

.PHONY: test-integ
test-integ: setup-codebuild-agent
	CODEBUILD_IMAGE_TAG=codebuild-agent test/integration/codebuild-local/test_all.sh test/integration/codebuild

.PHONY: build
build:
	rake build

.PHONY: run-local-ric
run-local-ric:
	scripts/run-local-ric.sh

.PHONY: test-dockerized
test-dockerized:
	@echo "Running dockerized tests locally..."
	@if [ -z "$(RUBY_VERSION)" ]; then \
		echo "Error: RUBY_VERSION is not set. Usage: make test-dockerized RUBY_VERSION=3.3"; \
		exit 1; \
	fi
	@echo "Building the lib..."
	$(MAKE) build
	@echo "Building Docker image for Ruby $(RUBY_VERSION)..."
	docker build . -t local/test -f Dockerfile.test --build-arg BASE_IMAGE=public.ecr.aws/lambda/ruby:$(RUBY_VERSION)
	@echo "Setting up containerized test runner..."
	@if [ ! -d ".test-runner" ]; then \
		echo "Cloning containerized-test-runner-for-aws-lambda..."; \
		git clone --quiet git@github.com:aws/containerized-test-runner-for-aws-lambda.git .test-runner; \
	fi
	@echo "Installing containerized test runner dependencies..."
	@PIP_INDEX_URL=https://pypi.org/simple pip install --quiet poetry-core 2>/dev/null || \
		PIP_INDEX_URL=https://pypi.org/simple pip install --user --quiet poetry-core 2>/dev/null || true
	@echo "Installing containerized test runner..."
	@cd .test-runner && \
		PIP_INDEX_URL=https://pypi.org/simple pip install --quiet . 2>/dev/null || \
		PIP_INDEX_URL=https://pypi.org/simple pip install --user --quiet .
	@echo "Running tests..."
	python -m containerized_test_runner.cli \
		--test-image local/test \
		--debug \
		--task-root $(CURDIR)/test/dockerized/tasks \
		./test/dockerized/suites/*.json

.PHONY: pr
pr: init test-unit test-smoke

define HELP_MESSAGE

Usage: $ make [TARGETS]

TARGETS

	build        Builds the package.
	clean        Cleans the working directory by removing built artifacts.
	init         Initialize and install the dependencies and dev-dependencies for this project.
	test-integ   Run Integration tests.
	test-unit    Run Unit Tests.
	test-smoke   Run Sanity/Smoke tests.
	test-dockerized  Run dockerized tests locally (requires RUBY_VERSION=X.X).
	run-local-ric  Run local RIC changes with Runtime Interface Emulator.
	pr           Perform all checks before submitting a Pull Request.

endef
