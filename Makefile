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
	pr           Perform all checks before submitting a Pull Request.

endef
