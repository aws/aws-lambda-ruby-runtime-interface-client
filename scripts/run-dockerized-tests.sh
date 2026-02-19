#!/bin/bash
set -e

# This script runs the containerized test runner in a Docker container
# It handles the complexity of Docker-in-Docker networking

RUBY_VERSION=$1
if [ -z "$RUBY_VERSION" ]; then
    echo "Error: RUBY_VERSION is required"
    echo "Usage: $0 <ruby_version>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Build the test runner image if needed
if [ ! "$(docker images -q test-runner:local 2> /dev/null)" ]; then
    echo "Building test runner Docker image..."
    docker build -t test-runner:local -f "$PROJECT_ROOT/Dockerfile.test-runner" "$PROJECT_ROOT"
fi

# Run the test runner with proper Docker socket access
docker run --rm \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_ROOT/test/dockerized/tasks:/tasks:ro" \
    -v "$PROJECT_ROOT/test/dockerized/suites:/suites:ro" \
    -e DOCKER_HOST=unix:///var/run/docker.sock \
    test-runner:local \
    --test-image local/test \
    --debug \
    --task-root /tasks \
    /suites/*.json
