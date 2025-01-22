# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require 'net/http'
require 'json'
require_relative 'lambda_errors'

class RapidClient
  LAMBDA_DEFAULT_SERVER_ADDRESS = '127.0.0.1:9001'
  LAMBDA_RUNTIME_API_VERSION = '2018-06-01'

  MAX_HEADER_SIZE_BYTES = 1024 * 1024
  LONG_TIMEOUT_MS = 1_000_000

  def initialize(server_address, user_agent)
    server_address ||= LAMBDA_DEFAULT_SERVER_ADDRESS
    @server_address = "http://#{server_address}/#{LAMBDA_RUNTIME_API_VERSION}"
    @user_agent = user_agent
  end

  def next_invocation
    next_invocation_uri = URI(@server_address + '/runtime/invocation/next')
    begin
      http = Net::HTTP.new(next_invocation_uri.host, next_invocation_uri.port)
      http.read_timeout = LONG_TIMEOUT_MS
      resp = http.start do |connection|
        connection.get(next_invocation_uri.path, { 'User-Agent' => @user_agent })
      end
      if resp.is_a?(Net::HTTPSuccess)
        request_id = resp['Lambda-Runtime-Aws-Request-Id']
        [request_id, resp]
      else
        raise LambdaErrors::InvocationError.new(
            "Received #{resp.code} when waiting for next invocation."
        )
      end
    rescue LambdaErrors::InvocationError => e
      raise e
    rescue StandardError => e
      raise LambdaErrors::InvocationError.new(e)
    end
  end

  def send_response(request_id:, response_object:, content_type: 'application/json')
    response_uri = URI(@server_address + "/runtime/invocation/#{request_id}/response")
    begin
      # unpack IO at this point
      if content_type == 'application/unknown'
        response_object = response_object.read
      end
      Net::HTTP.post(
          response_uri,
          response_object,
          { 'Content-Type' => content_type, 'User-Agent' => @user_agent }
      )
    rescue StandardError => e
      raise LambdaErrors::LambdaRuntimeError.new(e)
    end
  end

  def send_error_response(request_id:, error_object:, error:, xray_cause:)
    response_uri = URI(@server_address + "/runtime/invocation/#{request_id}/error")
    begin
      headers = { 'Lambda-Runtime-Function-Error-Type' => error.runtime_error_type, 'User-Agent' => @user_agent }
      headers['Lambda-Runtime-Function-XRay-Error-Cause'] = xray_cause if xray_cause.bytesize < MAX_HEADER_SIZE_BYTES
      Net::HTTP.post(
          response_uri,
          error_object.to_json,
          headers
      )
    rescue StandardError => e
      raise LambdaErrors::LambdaRuntimeError.new(e)
    end
  end

  def send_init_error(error_object:, error:)
    uri = URI("#{@server_address}/runtime/init/error")
    begin
      Net::HTTP.post(
          uri,
          error_object.to_json,
          { 'Lambda-Runtime-Function-Error-Type' => error.runtime_error_type, 'User-Agent' => @user_agent }
      )
    rescue StandardError => e
      raise LambdaErrors::LambdaRuntimeInitError.new(e)
    end
  end
end
