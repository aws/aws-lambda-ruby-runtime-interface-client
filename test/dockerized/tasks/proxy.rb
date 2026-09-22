# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# The image (see Dockerfile.test) runs with HTTP_PROXY pointed at an
# unreachable address and RIE's Runtime API bound to a non-loopback
# hostname. If the proxy-bypass fix (PR #68) is in place the RIC bypasses
# HTTP_PROXY for Runtime API calls and this handler runs to completion,
# returning "success". Without the fix the RIC would try to reach the
# unreachable proxy for next_invocation and this handler would never run.

def check_proxy_bypass(event:, context:)
  'success'
end
