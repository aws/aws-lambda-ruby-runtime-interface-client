#!/bin/sh
# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#

set -eu

if [ "$#" -ne 1 ]; then
  echo "entrypoint requires the handler name as first argument" 1>&2
  exit 142
fi
export _HANDLER="$1"

# Resolve the container's own hostname to its non-loopback IPv4 (docker
# writes this to /etc/hosts for us on eth0).
RIC_HOST="$(getent hosts "$HOSTNAME" | awk '{print $1; exit}')"
if [ -z "$RIC_HOST" ]; then
  echo "entrypoint could not resolve \$HOSTNAME ($HOSTNAME)" 1>&2
  exit 143
fi

exec /usr/local/bin/aws-lambda-rie \
    --runtime-api-address "$RIC_HOST:9001" \
    /var/runtime/bootstrap
