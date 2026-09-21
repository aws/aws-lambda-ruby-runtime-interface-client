# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/lambda_errors'
require_relative '../../lib/aws_lambda_ric/lambda_server'
require 'net/http'
require 'socket'
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

  def test_next_invocation_handles_different_signals
    ['INT', 'TERM', 'QUIT'].each do |signal|
      http_mock = Minitest::Mock.new
      http_mock.expect(:read_timeout=, nil, [RapidClient::LONG_TIMEOUT_MS])
      http_mock.expect(:start, nil) { raise SignalException.new(signal) }
      
      Net::HTTP.stub :new, http_mock do
        error = assert_raises(LambdaErrors::InvocationError) do
          @under_test.next_invocation
        end

        assert_match(/Next invocation HTTP request from the runtime interface client was interrupted with a SIG#{signal} SIGNAL, gracefully shutting down./, error.message)
        http_mock.verify
      end
    end
  end

  def test_post_invocation_error_with_large_xray_cause
    large_xray_cause = ('a' * 1024 * 1024)[0..-2]
    headers = {'Lambda-Runtime-Function-Error-Type' => @error.runtime_error_type,
               'Lambda-Runtime-Function-XRay-Error-Cause' => large_xray_cause,
               'User-Agent' => @mock_user_agent}
    conn_mock = mock_post_connection(@error_uri.path, @error.to_lambda_response.to_json, headers)

    Net::HTTP.stub(:new, conn_mock, [@error_uri.host, @error_uri.port]) do
      @under_test.send_error_response(
        request_id: @request_id,
        error_object: @error.to_lambda_response,
        error: @error,
        xray_cause: large_xray_cause
      )
    end

    assert_mock conn_mock
  end

  def test_post_invocation_error_with_too_large_xray_cause
    too_large_xray_cause = 'a' * 1024 * 1024
    headers = {'Lambda-Runtime-Function-Error-Type' => @error.runtime_error_type,
               'User-Agent' => @mock_user_agent}
    conn_mock = mock_post_connection(@error_uri.path, @error.to_lambda_response.to_json, headers)

    Net::HTTP.stub(:new, conn_mock, [@error_uri.host, @error_uri.port]) do
      @under_test.send_error_response(
        request_id: @request_id,
        error_object: @error.to_lambda_response,
        error: @error,
        xray_cause: too_large_xray_cause
      )
    end

    assert_mock conn_mock
  end

  # Regression: with a proxy in the environment, the response must still reach
  # the Runtime API directly
  def test_send_response_reaches_api_and_not_proxy_when_proxy_is_set
    api = RecordingServer.new
    proxy = RecordingServer.new

    ['HTTP_PROXY', 'http_proxy'].each do |var|
      api.reset
      proxy.reset
      env_stub(var, "http://#{proxy.address}") do
        client = RapidClient.new(api.address, @mock_user_agent)
        client.send_response(request_id: @request_id, response_object: 'response')

        assert_equal 1, api.hits, 'response should reach the Runtime API'
        assert_equal 0, proxy.hits, "response must not be routed through #{var}"
      end
    end
  ensure
    api&.close
    proxy&.close
  end

  def mock_post_connection(path, body, headers)
    conn_mock = Minitest::Mock.new
    conn_mock.expect(:start, true) do |&block|
      block.call(conn_mock)
      true
    end
    conn_mock.expect(:post, nil, [path, body, headers])
    conn_mock
  end

  def env_stub(name, value)
    previous = ENV[name]
    ENV[name] = value
    yield
  ensure
    ENV[name] = previous
  end

  def mock_next_invocation_response()
    mock_response = Net::HTTPSuccess.new(1.0, '200', 'OK')
    mock_response['Lambda-Runtime-Aws-Request-Id'] = @request_id
    mock_response
  end

  def mock_next_invocation_request(mock_response)
    get_mock = Minitest::Mock.new
    get_mock.expect(:read_timeout=, nil, [RapidClient::LONG_TIMEOUT_MS])
    get_mock.expect(:start, mock_response) do |&block|
      block.call(get_mock)
    end
    get_mock.expect(:get, mock_response, ['/2018-06-01/runtime/invocation/next', {'User-Agent' => @mock_user_agent}])
    get_mock
  end

  def assert_next_invocation(get_mock, expected_tenant_id)
    Net::HTTP.stub(:new, get_mock, ['127.0.0.1', 9001]) do
      request_id, response = @under_test.next_invocation
      assert_equal @request_id, request_id
      assert_equal expected_tenant_id, response['Lambda-Runtime-Aws-Tenant-Id']
    end
  end

  def test_next_invocation_without_tenant_id_header
    mock_response = mock_next_invocation_response()
    get_mock = mock_next_invocation_request(mock_response)
    assert_next_invocation(get_mock, nil)
    assert_mock get_mock
  end

  def test_next_invocation_with_tenant_id_header
    mock_response = mock_next_invocation_response()
    mock_response['Lambda-Runtime-Aws-Tenant-Id'] = 'blue'

    get_mock = mock_next_invocation_request(mock_response)  
    assert_next_invocation(get_mock, 'blue')
    assert_mock get_mock
  end
  
  def test_next_invocation_with_empty_tenant_id_header
    mock_response = mock_next_invocation_response()
    mock_response['Lambda-Runtime-Aws-Tenant-Id'] = ''
    
    get_mock = mock_next_invocation_request(mock_response)  
    assert_next_invocation(get_mock, '')
    assert_mock get_mock
  end
  
  def test_next_invocation_with_null_tenant_id_header
    mock_response = mock_next_invocation_response()
    mock_response['Lambda-Runtime-Aws-Tenant-Id'] = nil

    get_mock = mock_next_invocation_request(mock_response)  
    assert_next_invocation(get_mock, nil)
    assert_mock get_mock
  end
end

# A minimal HTTP server that binds to a non-loopback address and counts the
# requests it receives. Non-loopback matters: Net::HTTP never proxies loopback,
# so a 127.0.0.1 target would bypass the proxy.
class RecordingServer
  def initialize
    ip = Socket.ip_address_list.find { |a| a.ipv4? && !a.ipv4_loopback? && !a.ipv4_multicast? }
    raise 'no non-loopback IPv4 interface available' unless ip

    @server = TCPServer.new(ip.ip_address, 0)
    @hits = 0
    @lock = Mutex.new
    @thread = Thread.new { accept_loop }
  end

  def address
    "#{@server.addr[3]}:#{@server.addr[1]}"
  end

  def hits
    @lock.synchronize { @hits }
  end

  def reset
    @lock.synchronize { @hits = 0 }
  end

  def close
    @thread&.kill
    @server&.close
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      @lock.synchronize { @hits += 1 }
      drain_request(client)
      client.write("HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\n\r\n")
      client.close
    end
  rescue IOError, Errno::EBADF
    # server closed
  end

  def drain_request(client)
    content_length = 0
    while (line = client.gets) && line != "\r\n"
      content_length = line.split(':', 2).last.to_i if line =~ /\AContent-Length:/i
    end
    client.read(content_length) if content_length.positive?
  end
end
