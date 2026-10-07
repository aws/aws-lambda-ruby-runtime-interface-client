# frozen_string_literal: true

class LambdaContext
  # Allowlist of W3C trace-context fields that may be surfaced through
  # LambdaContext#w3c. Any other key carried on clientContext.w3c is ignored,
  # and any allowlisted key whose value is not a string is dropped.
  W3C_ALLOWED_FIELDS = %w[traceparent tracestate baggage].freeze

  attr_reader :aws_request_id, :invoked_function_arn, :log_group_name,
              :log_stream_name, :function_name, :memory_limit_in_mb, :function_version,
              :identity, :tenant_id, :client_context, :deadline_ms

  def initialize(request)
    @clock_diff = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond) - Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    @deadline_ms = request['Lambda-Runtime-Deadline-Ms'].to_i
    @aws_request_id = request['Lambda-Runtime-Aws-Request-Id']
    @invoked_function_arn = request['Lambda-Runtime-Invoked-Function-Arn']
    @log_group_name = ENV['AWS_LAMBDA_LOG_GROUP_NAME']
    @log_stream_name = ENV['AWS_LAMBDA_LOG_STREAM_NAME']
    @function_name = ENV['AWS_LAMBDA_FUNCTION_NAME']
    @memory_limit_in_mb = ENV['AWS_LAMBDA_FUNCTION_MEMORY_SIZE']
    @function_version = ENV['AWS_LAMBDA_FUNCTION_VERSION']
    @identity = JSON.parse(request['Lambda-Runtime-Cognito-Identity']) unless request['Lambda-Runtime-Cognito-Identity'].to_s.empty?
    @tenant_id = request['Lambda-Runtime-Aws-Tenant-Id'] unless request['Lambda-Runtime-Aws-Tenant-Id'].to_s.empty?
    @w3c_fields = {}
    unless request['Lambda-Runtime-Client-Context'].to_s.empty?
      client_context = JSON.parse(request['Lambda-Runtime-Client-Context'])
      @w3c_fields = self.class.extract_and_strip_w3c(client_context)
      @client_context = client_context
    end
  end

  def get_remaining_time_in_millis
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) + @clock_diff
    remaining = @deadline_ms - now
    remaining.positive? ? remaining : 0
  end

  # Return the W3C trace-context captured at invoke time, as a fresh copy so
  # callers cannot mutate the context's internal state.
  def w3c
    @w3c_fields.dup
  end

  # Pop "w3c" out of the parsed client_context hash and return a normalized
  # copy of its allowlisted string fields (see W3C_ALLOWED_FIELDS).
  def self.extract_and_strip_w3c(client_context)
    return {} unless client_context.is_a?(Hash)
    return {} unless client_context.key?('w3c')

    raw_w3c = client_context.delete('w3c')
    return {} unless raw_w3c.is_a?(Hash)

    fields = {}
    W3C_ALLOWED_FIELDS.each do |key|
      value = raw_w3c[key]
      fields[key] = value if value.is_a?(String)
    end
    fields
  end
end
