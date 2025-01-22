# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require_relative 'aws_lambda_ric/lambda_errors'
require_relative 'aws_lambda_ric/lambda_server'
require_relative 'aws_lambda_ric/lambda_handler'
require_relative 'aws_lambda_ric/lambda_context'
require_relative 'aws_lambda_ric/lambda_logger'
require_relative 'aws_lambda_ric/lambda_log_formatter'
require_relative 'aws_lambda_ric/logger_patch'
require_relative 'aws_lambda_ric/telemetry_log_sink'
require_relative 'aws_lambda_ric/aws_lambda_marshaller'
require_relative 'aws_lambda_ric/xray_cause'
require_relative 'aws_lambda_ric/version'
require 'logger'

$stdout.sync = true # Ensures that logs are flushed promptly.

module AwsLambdaRIC

  class Error < StandardError; end

  def self.get_user_agent
    ruby_version = RUBY_VERSION.to_s
    version = AwsLambdaRIC::VERSION

    "aws-lambda-ruby/#{ruby_version}-#{version}"
  end

  # Loads the user code and runs it upon invocation
  class LambdaRunner

    ENV_VAR_RUNTIME_API = 'AWS_LAMBDA_RUNTIME_API'

    def initialize(runtime_server_addr, user_agent)
      @lambda_server = RapidClient.new(runtime_server_addr, user_agent)
      @runtime_loop_active = true # if false, we will exit the program
      @exit_code = 0
    end

    def run(app_root, handler)

      $LOAD_PATH.unshift(app_root) unless $LOAD_PATH.include?(app_root)

      begin
        @lambda_handler = LambdaHandler.new(env_handler: handler)
        require @lambda_handler.handler_file_name
        start_runtime_loop
      rescue Exception => e # which includes LoadError or any exception within static user code
        @runtime_loop_active = false
        @exit_code = -4
        send_init_error_to_server(e)
      ensure
        TelemetryLogger.close
      end

      exit(@exit_code)
    end

    private

    def start_runtime_loop
      while @runtime_loop_active
        lambda_invocation_request = wait_for_invocation
        run_user_code(lambda_invocation_request)
      end
    end

    def wait_for_invocation
      request_id, raw_request = @lambda_server.next_invocation
      $_global_aws_request_id = request_id
      if (trace_id = raw_request['Lambda-Runtime-Trace-Id'])
        ENV['_X_AMZN_TRACE_ID'] = trace_id
      end
      request = AwsLambda::Marshaller.marshall_request(raw_request)

      LambdaInvocationRequest.new(request_id, raw_request, request, trace_id)
    rescue LambdaErrors::InvocationError => e
      @runtime_loop_active = false # ends the loop
      raise e # ends the process
    end

    def run_user_code(lambda_invocation_request)
      context = LambdaContext.new(lambda_invocation_request.raw_request) # pass in opts

      # start of user code
      handler_response, content_type = @lambda_handler.call_handler(
        request: lambda_invocation_request.request,
        context: context
      )
      # end of user code

      @lambda_server.send_response(
        request_id: lambda_invocation_request.request_id,
        response_object: handler_response,
        content_type: content_type
      )

    rescue LambdaErrors::LambdaHandlerError => e
      LambdaLogger.log_error(exception: e, message: 'Error raised from handler method')
      send_error_response(lambda_invocation_request, e)
    rescue LambdaErrors::LambdaHandlerCriticalException => e
      LambdaLogger.log_error(exception: e, message: 'Critical exception from handler')
      send_error_response(lambda_invocation_request, e, -1, false)
    rescue LambdaErrors::LambdaRuntimeError => e
      send_error_response(lambda_invocation_request, e, -2, false)
    end

    def send_init_error_to_server(err)
      ex = LambdaErrors::LambdaRuntimeInitError.new(err)
      LambdaLogger.log_error(exception: ex, message: "Init error when loading handler #{@env_handler}")
      @lambda_server.send_init_error(error_object: ex.to_lambda_response, error: ex)
    end

    def send_error_response(lambda_invocation, err, exit_code = nil, runtime_loop_active = true)
      error_object = err.to_lambda_response
      @lambda_server.send_error_response(
        request_id: lambda_invocation.request_id,
        error_object: error_object,
        error: err,
        xray_cause: XRayCause.new(error_object).as_json
      )

      @exit_code = exit_code unless exit_code.nil?
      @runtime_loop_active = runtime_loop_active
    end
  end

  # Helper class to for mutating std logger with TelemetryLog
  class TelemetryLogger

    ENV_VAR_TELEMETRY_LOG_FD = '_LAMBDA_TELEMETRY_LOG_FD'

    class << self
      attr_accessor :telemetry_log_fd_file, :telemetry_log_sink

      def close
        telemetry_log_fd_file&.close
      end
    end

    def initialize(telemetry_log_fd)
      fd = telemetry_log_fd.to_i
      AwsLambdaRIC::TelemetryLogger.telemetry_log_fd_file = IO.new(fd, 'wb')
      AwsLambdaRIC::TelemetryLogger.telemetry_log_fd_file.sync = true

      AwsLambdaRIC::TelemetryLogger.telemetry_log_sink = TelemetryLogSink.new(file: AwsLambdaRIC::TelemetryLogger.telemetry_log_fd_file)

      mutate_std_logger
      mutate_kernel_puts
    rescue Errno::ENOENT, Errno::EBADF
      # If File.open() fails, then the mutation won't happen and the default behaviour (print to stdout) will prevail
    end

    def self.from_env()
      if ENV.key?(ENV_VAR_TELEMETRY_LOG_FD)
        fd = ENV.fetch(AwsLambdaRIC::TelemetryLogger::ENV_VAR_TELEMETRY_LOG_FD)
        ENV.delete(AwsLambdaRIC::TelemetryLogger::ENV_VAR_TELEMETRY_LOG_FD)
        AwsLambdaRIC::TelemetryLogger.new(fd)
      end
    end

    private

    def mutate_std_logger
      Logger.class_eval do
        prepend LoggerPatch
      end
    end

    def mutate_kernel_puts
      Kernel.module_eval do
        def puts(*arg)
          msg = arg.flatten.collect { |a| a.to_s.encode('UTF-8') }.join("\n")
          if msg[-1] != "\n"
            msg += "\n"
          end
          AwsLambdaRIC::TelemetryLogger.telemetry_log_sink.write(msg)
          return nil
        end
      end
    end
  end

  # Represents a single Lambda Invocation Request
  class LambdaInvocationRequest

    attr_accessor :request_id, :raw_request, :request, :trace_id

    def initialize(request_id, raw_request, request, trace_id)
      @request_id = request_id
      @raw_request = raw_request
      @request = request
      @trace_id = trace_id
    end
  end

  class Bootstrap

    def start
      AwsLambdaRIC::TelemetryLogger::from_env()
      bootstrap_handler
    end

    def fetch_runtime_server
      ENV.fetch(AwsLambdaRIC::LambdaRunner::ENV_VAR_RUNTIME_API)
    rescue KeyError
      puts 'Failed to get runtime server address from AWS_LAMBDA_RUNTIME_API env variable'
      exit(-2)
    end

    def bootstrap_handler
      if ENV['_HANDLER'] == nil
        puts 'No handler specified, exiting Runtime Interface Client.'
        exit
      end
      app_root = Dir.pwd
      handler = ENV['_HANDLER']
      lambda_runner = AwsLambdaRIC::LambdaRunner.new(fetch_runtime_server, AwsLambdaRIC::get_user_agent)
      lambda_runner.run(app_root, handler)
    end
  end
end
