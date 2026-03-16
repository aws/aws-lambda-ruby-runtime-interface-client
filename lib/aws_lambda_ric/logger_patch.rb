# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require 'logger'
require_relative 'lambda_log_formatter'

module LoggerPatch
  LOG_LEVEL_MAP = {
    'TRACE' => Logger::DEBUG,
    'DEBUG' => Logger::DEBUG,
    'INFO' => Logger::INFO,
    'WARN' => Logger::WARN,
    'ERROR' => Logger::ERROR,
    'FATAL' => Logger::FATAL
  }.freeze

  class << self
    attr_reader :aws_lambda_log_format, :aws_lambda_log_level

    def refresh_runtime_config!
      @aws_lambda_log_format = ENV.fetch('AWS_LAMBDA_LOG_FORMAT', '').upcase
      env_level = ENV.fetch('AWS_LAMBDA_LOG_LEVEL', nil)
      @aws_lambda_log_level = LOG_LEVEL_MAP[env_level&.upcase]
    end

    def json_format?
      @aws_lambda_log_format == 'JSON'
    end
  end

  refresh_runtime_config!

  # shift_size default to 1 megabyte, matching Ruby Logger's default log rotation size.
  def initialize(logdev, shift_age = 0, shift_size = 1_048_576, **kwargs)
    level_was_provided = kwargs.key?(:level)
    kwargs = {
      level: Logger::DEBUG,
      progname: nil,
      formatter: nil,
      datetime_format: nil,
      binmode: false,
      shift_period_suffix: '%Y%m%d'
    }.merge(kwargs)

    logdev_override = logdev

    if !logdev || logdev == $stdout || logdev == $stderr
      telemetry_sink = AwsLambdaRIC::TelemetryLogger.telemetry_log_sink
      logdev_override = telemetry_sink || logdev
      kwargs[:formatter] ||= LoggerPatch.json_format? ? JsonLogFormatter.new : LogFormatter.new
      kwargs[:level] = LoggerPatch.aws_lambda_log_level if !level_was_provided && LoggerPatch.aws_lambda_log_level
    end

    super(logdev_override, shift_age, shift_size, **kwargs)
  end
end
