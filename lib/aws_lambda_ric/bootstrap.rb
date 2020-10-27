require_relative '../aws_lambda_ric'

# Bootstrap runtime
module Bootstrap

  def self.start
    bootstrap_telemetry_log_sink
    bootstrap_handler
  end

  def self.fetch_runtime_server
    ENV.fetch(AwsLambdaRuntimeInterfaceClient::LambdaRunner::ENV_VAR_RUNTIME_API)
  rescue KeyError
    puts 'Failed to get runtime server address from AWS_LAMBDA_RUNTIME_API env variable'
    exit(-2)
  end

  def self.bootstrap_telemetry_log_sink(path_to_fd='/proc/self/fd/')
    fd = ENV.fetch(AwsLambdaRuntimeInterfaceClient::TelemetryLoggingHelper::ENV_VAR_TELEMETRY_LOG_FD)
    ENV.delete(AwsLambdaRuntimeInterfaceClient::TelemetryLoggingHelper::ENV_VAR_TELEMETRY_LOG_FD)
    AwsLambdaRuntimeInterfaceClient::TelemetryLoggingHelper.new(fd, path_to_fd)
  rescue KeyError
    puts 'Skipped bootstraping TelemetryLog'
  end

  def self.bootstrap_handler
    if ARGV.empty?
      puts 'No handler specified, exiting Runtime Interface Client.'
      exit
    end
    app_root = Dir.pwd
    handler = ARGV[0]
    lambda_runner = AwsLambdaRuntimeInterfaceClient::LambdaRunner.new(fetch_runtime_server)
    puts "Executing '#{handler}' in function directory '#{app_root}'"
    lambda_runner.run(app_root, handler)
  end

end