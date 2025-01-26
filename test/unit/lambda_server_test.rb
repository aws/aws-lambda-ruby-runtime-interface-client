# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/lambda_errors'
require_relative '../../lib/aws_lambda_ric/lambda_server'
require 'net/http'
require 'minitest/autorun'

class LambdaServerTest < Minitest::Test
  def setup
    @server_address = '127.0.0.1:9001'
    @request_id = 'test_id'
    @error = LambdaErrors::LambdaRuntimeError.new(StandardError.new('User error, replace user'))
    @error_uri = URI("http://#{@server_address}/2018-06-01/runtime/invocation/#{@request_id}/error")
    @mock_user_agent = 'mock-user-agent'
    @under_test = RapidClient.new(@server_address, @mock_user_agent)
  end

  def test_post_invocation_error_with_large_xray_cause
    large_xray_cause = ('a' * 1024 * 1024)[0..-2]
    headers = {'Lambda-Runtime-Function-Error-Type' => @error.runtime_error_type,
               'Lambda-Runtime-Function-XRay-Error-Cause' => large_xray_cause,
               'User-Agent' => @mock_user_agent}
    post_mock = Minitest::Mock.new
    post_mock.expect :call, nil, [@error_uri, @error.to_lambda_response.to_json, headers]

    Net::HTTP.stub(:post, post_mock) do
      @under_test.send_error_response(
        request_id: @request_id,
        error_object: @error.to_lambda_response,
        error: @error,
        xray_cause: large_xray_cause
      )
    end

    assert_mock post_mock
  end

  def test_post_invocation_error_with_too_large_xray_cause
    too_large_xray_cause = 'a' * 1024 * 1024
    headers = {'Lambda-Runtime-Function-Error-Type' => @error.runtime_error_type,
               'User-Agent' => @mock_user_agent}
    post_mock = Minitest::Mock.new
    post_mock.expect :call, nil, [@error_uri, @error.to_lambda_response.to_json, headers]

    Net::HTTP.stub(:post, post_mock) do
      @under_test.send_error_response(
        request_id: @request_id,
        error_object: @error.to_lambda_response,
        error: @error,
        xray_cause: too_large_xray_cause
      )
    end

    assert_mock post_mock
  end
end
