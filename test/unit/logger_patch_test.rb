# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/logger_patch'
require 'logger'
require 'stringio'
require 'minitest/autorun'

module AwsLambdaRIC
  class TelemetryLogger
    class << self
      attr_accessor :telemetry_log_sink
    end
  end
end

class LoggerPatchTest < Minitest::Test
  def setup
    @original_log_format = ENV['AWS_LAMBDA_LOG_FORMAT']
    @original_log_level = ENV['AWS_LAMBDA_LOG_LEVEL']
    AwsLambdaRIC::TelemetryLogger.telemetry_log_sink = nil

    @patched_class = Class.new do
      prepend LoggerPatch
      attr_reader :super_args, :super_kwargs

      def initialize(*args, **kwargs)
        @super_args = args
        @super_kwargs = kwargs
      end
    end
  end

  def teardown
    ENV['AWS_LAMBDA_LOG_FORMAT'] = @original_log_format
    ENV['AWS_LAMBDA_LOG_LEVEL'] = @original_log_level
  end

  def test_uses_text_formatter_for_stdout_by_default
    ENV['AWS_LAMBDA_LOG_FORMAT'] = 'TEXT'
    ENV.delete('AWS_LAMBDA_LOG_LEVEL')
    LoggerPatch.refresh_runtime_config!

    instance = @patched_class.new($stdout)

    assert_same $stdout, instance.super_args[0]
    assert_instance_of LogFormatter, instance.super_kwargs[:formatter]
    assert_equal Logger::DEBUG, instance.super_kwargs[:level]
  end

  def test_uses_json_formatter_when_requested
    ENV['AWS_LAMBDA_LOG_FORMAT'] = 'json'
    ENV.delete('AWS_LAMBDA_LOG_LEVEL')
    LoggerPatch.refresh_runtime_config!

    instance = @patched_class.new($stdout)

    assert_instance_of JsonLogFormatter, instance.super_kwargs[:formatter]
  end

  def test_maps_trace_level_to_debug
    ENV['AWS_LAMBDA_LOG_FORMAT'] = 'JSON'
    ENV['AWS_LAMBDA_LOG_LEVEL'] = 'trace'
    LoggerPatch.refresh_runtime_config!

    instance = @patched_class.new($stdout)

    assert_equal Logger::DEBUG, instance.super_kwargs[:level]
  end

  def test_does_not_override_explicit_formatter_or_level
    custom_formatter = Logger::Formatter.new
    ENV['AWS_LAMBDA_LOG_FORMAT'] = 'JSON'
    ENV['AWS_LAMBDA_LOG_LEVEL'] = 'ERROR'
    LoggerPatch.refresh_runtime_config!

    instance = @patched_class.new($stdout, formatter: custom_formatter, level: Logger::WARN)

    assert_same custom_formatter, instance.super_kwargs[:formatter]
    assert_equal Logger::WARN, instance.super_kwargs[:level]
  end

  def test_keeps_custom_logdev_unmodified
    io = StringIO.new
    ENV['AWS_LAMBDA_LOG_FORMAT'] = 'JSON'
    ENV['AWS_LAMBDA_LOG_LEVEL'] = 'ERROR'
    LoggerPatch.refresh_runtime_config!

    instance = @patched_class.new(io)

    assert_same io, instance.super_args[0]
    assert_nil instance.super_kwargs[:formatter]
    assert_equal Logger::DEBUG, instance.super_kwargs[:level]
  end
end
