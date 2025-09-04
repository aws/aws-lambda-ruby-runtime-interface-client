#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"


IMAGE_TAG="ruby-ric-rie-test"
HANDLER="${1:-app.App::Handler.process}"

echo "Starting RIE test setup for Ruby..."

echo "Building test Docker image..."
docker build -t "$IMAGE_TAG" -f "$PROJECT_ROOT/Dockerfile.rie" "$PROJECT_ROOT"

echo "Starting test container on port 9000..."
echo ""
echo "In another terminal, invoke with:"
echo "curl -s -X POST -H 'Content-Type: application/json' \"http://localhost:9000/2015-03-31/functions/function/invocations\" -d '{\"message\":\"test\"}'"
echo ""

exec docker run -it -p 9000:8080 -e _HANDLER="$HANDLER" "$IMAGE_TAG"