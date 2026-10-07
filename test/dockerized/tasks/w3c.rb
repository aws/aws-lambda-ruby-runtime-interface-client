# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

def get_w3c(event:, context:)
  context.w3c
end

def get_w3c_and_source(event:, context:)
  client_context = context.client_context
  {
    w3c: context.w3c,
    clientContextIsDefined: !client_context.nil?,
    clientContextHasW3c: !client_context.nil? && client_context.key?('w3c'),
    clientContext: client_context
  }
end

def echo_client_context(event:, context:)
  context.client_context
end

def w3c_is_callable(event:, context:)
  { isCallable: context.respond_to?(:w3c) }
end
