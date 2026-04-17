#!/bin/bash
# Run a single integration test locally.
# Usage: ./test/integration/run-local.sh <distro> <distro_version> <runtime_version>
# Example: ./test/integration/run-local.sh alpine 3.19 3.3

set -euo pipefail

DISTRO="${1:?Usage: $0 <distro> <distro_version> <runtime_version>}"
DISTRO_VERSION="${2:?Usage: $0 <distro> <distro_version> <runtime_version>}"
RUNTIME_VERSION="${3:?Usage: $0 <distro> <distro_version> <runtime_version>}"

TEST_NAME="ric-local-test"
SCRATCH_DIR=".scratch"

# Determine executable path based on distro
case "$DISTRO" in
  alpine|debian)
    EXECUTABLE="/usr/local/bundle/bin/aws_lambda_ric"
    ;;
  al2023|amazonlinux|ubuntu)
    EXECUTABLE="/usr/local/bin/aws_lambda_ric"
    ;;
  *)
    echo "Unknown distro: $DISTRO" >&2
    exit 1
    ;;
esac

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${TEST_NAME}-app" "${TEST_NAME}-tester" 2>/dev/null || true
  docker network rm "${TEST_NAME}-net" 2>/dev/null || true
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

# Download RIE
mkdir -p "$SCRATCH_DIR"
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  RIE="aws-lambda-rie"
elif [ "$ARCH" = "aarch64" ]; then
  RIE="aws-lambda-rie-arm64"
else
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
fi
echo "Downloading ${RIE} from GitHub..."
curl -sSL "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/${RIE}" -o "${SCRATCH_DIR}/${RIE}"
chmod +x "${SCRATCH_DIR}/${RIE}"

# Build image
DOCKERFILE="test/integration/docker/Dockerfile.echo.${DISTRO}"
TMPFILE="${SCRATCH_DIR}/Dockerfile.tmp"
cp "$DOCKERFILE" "$TMPFILE"
echo "COPY ${SCRATCH_DIR}/${RIE} /usr/bin/${RIE}" >> "$TMPFILE"

IMAGE_TAG="ric-test-${DISTRO}-${DISTRO_VERSION}:${RUNTIME_VERSION}"
echo "Building ${IMAGE_TAG}..."
docker build . \
  -f "$TMPFILE" \
  -t "$IMAGE_TAG" \
  --build-arg RUNTIME_VERSION="$RUNTIME_VERSION" \
  --build-arg DISTRO_VERSION="$DISTRO_VERSION"

# Run test
docker network create "${TEST_NAME}-net"

docker run \
  --detach \
  --name "${TEST_NAME}-app" \
  --network "${TEST_NAME}-net" \
  --entrypoint="" \
  "$IMAGE_TAG" \
  sh -c "/usr/bin/${RIE} ${EXECUTABLE} app.App::Handler.process"

sleep 2

docker run \
  --name "${TEST_NAME}-tester" \
  --env "TARGET=${TEST_NAME}-app" \
  --network "${TEST_NAME}-net" \
  --entrypoint="" \
  "$IMAGE_TAG" \
  sh -c 'curl -sS -X POST "http://${TARGET}:8080/2015-03-31/functions/function/invocations" -d "{}" --max-time 10'

ACTUAL="$(docker logs --tail 1 "${TEST_NAME}-tester" | xargs)"
EXPECTED="success"

echo ""
echo "=== App logs ==="
docker logs "${TEST_NAME}-app" 2>&1 || true
echo ""

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "FAIL: ${DISTRO}-${DISTRO_VERSION}:${RUNTIME_VERSION} — expected '${EXPECTED}', got '${ACTUAL}'"
  exit 1
fi

echo "PASS: ${DISTRO}-${DISTRO_VERSION}:${RUNTIME_VERSION}"
