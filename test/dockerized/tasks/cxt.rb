# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.

def get_context(event:,context:)
    {
      function_name: context.function_name,
      deadline_ns: context.deadline_ns,
      aws_request_id: context.aws_request_id,
      invoked_function_arn: context.invoked_function_arn,
      log_group_name: context.log_group_name,
      log_stream_name: context.log_stream_name,
      memory_limit_in_mb: context.memory_limit_in_mb,
      function_version: context.function_version
    }
  end
  
  def get_cognito_pool_id(event:,context:)
    { cognito_pool_id: context.identity["cognitoIdentityPoolId"]}
  end
  
  def get_cognito_identity_id(event:,context:)
    { cognito_identity_id: context.identity["cognitoIdentityId"] }
  end
  
  def echo_context(event:,context:)
    context.client_context
  end
  
  def get_remaining_time_from_context(event:, context:)
      before = context.get_remaining_time_in_millis()
      sleep(event['sleepTimeSeconds'])
      return { elapsedTime: before - context.get_remaining_time_in_millis() }
  end