require './lib/aws_lambda_ric/lambda_handler'
require './lib/aws_lambda_ric/lambda_context'
require './lib/aws_lambda_ric/aws_lambda_marshaller'
require './lib/aws_lambda_ric/telemetry_log_sink'
require './lib/aws_lambda_ric/bootstrap'
require 'securerandom'
require 'minitest/autorun'
require 'logger'


class HarnessTests < Minitest::Test
  test_suite = open('test/unit/harness-suite.json')
  json = test_suite.read

  parsed_json = JSON.parse(json)
  parsed_json['tests'].each do |test|
    test_name = test["name"]
    if !test_name.start_with?('test')
        test_name = "test_#{test_name}"
    end

    handler = test['handler']

    event = test['request']

    assertion = test['assertion']
  
    env_vars = test['environmentVariables']

    context = {}
    if test.key?('cognitoIdentity')
      context['Lambda-Runtime-Cognito-Identity'] = test['cognitoIdentity'].to_json
    end
    if test.key?('clientContext')
      context['Lambda-Runtime-Client-Context'] = test['clientContext'].to_json
    end
    if test.key?('xray')
      context['Lambda-Runtime-Trace-Id'] = test['xray']['traceId']
    end



    define_method(test_name) do
      # Logger uses request id
      $_global_aws_request_id = SecureRandom.uuid

      # Set up env variables for the test
      if env_vars
        env_vars.each do |env_var, value|
          ENV[env_var] = value
        end
      end

      # Set up Telemetry Log fd
      Bootstrap::bootstrap_telemetry_log_sink('')

      context = LambdaContext.new(context)

      # If the test is expecting an error
      if assertion.key?('errorType')
        begin
          lambda_handler = LambdaHandler.new(env_handler: "resources/runtime_handlers/#{handler}")
          require_relative lambda_handler.handler_file_name
          handler_response, content_type = lambda_handler.call_handler(
            request: event,
            context: context
          )
        rescue LambdaErrors::LambdaError => e
          assert_equal(assertion['errorType'], e.runtime_error_type)
        rescue StandardError => e
          assert_equal e.class.to_s, assertion['errorType'][/<(.*?)>/, 1]
        rescue ScriptError => e
          assert_equal e.class.to_s, assertion['errorType'][/<(.*?)>/, 1]
        end
      # If the test is expecting an assertion
      else
        lambda_handler = LambdaHandler.new(env_handler: "resources/runtime_handlers/#{handler}")
        require_relative lambda_handler.handler_file_name
        handler_response, content_type = lambda_handler.call_handler(
          request: event,
          context: context
        )

        if assertion.key?('transform')
          transform = assertion['transform']
          assert_equal assertion['response'], handler_response.to_s.match?(/#{transform}/)
        else
          assert_equal assertion['response'].to_json, handler_response
        end
      end

      # Revert changes made for tests that use Telemetry Log fd
      if ENV.key?('_LAMBDA_TELEMETRY_LOG_FD')
        Logger.class_eval do
          alias_method :initialize, :orig_initialize
        end
  
        Kernel.module_eval do
          def puts(*args)
            $stdout.puts(*args)
          end
        end
  
        File.open('test/unit/resources/fd/test_fd', 'w') {|file| file.truncate(0) }
      end

      # Delete env vars set for the test
      if env_vars
          env_vars.each do |env_var, value|
            ENV.delete(env_var)
        end
      end
    end
  end
end