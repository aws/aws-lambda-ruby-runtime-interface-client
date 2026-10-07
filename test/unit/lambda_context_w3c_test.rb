# frozen_string_literal: true

require 'json'
require_relative '../../lib/aws_lambda_ric/lambda_context'
require 'minitest/autorun'
require 'test/unit/assertions'

include Test::Unit::Assertions

class LambdaContextW3CTest < Minitest::Test
  def build_context(client_context_hash)
    request = {
      'Lambda-Runtime-Aws-Request-Id' => 'invoke-id-w3c',
      'Lambda-Runtime-Deadline-Ms' => '0',
      'Lambda-Runtime-Invoked-Function-Arn' => 'arn:test:w3c'
    }
    unless client_context_hash.nil?
      request['Lambda-Runtime-Client-Context'] = JSON.generate(client_context_hash)
    end
    LambdaContext.new(request)
  end

  def test_w3c_returns_empty_when_no_client_context
    assert_equal({}, build_context(nil).w3c)
  end

  def test_w3c_returns_empty_and_leaves_client_context_untouched_when_no_w3c_key
    context = build_context({ 'custom' => { 'value' => 'test' } })
    assert_equal({}, context.w3c)
    assert_equal({ 'custom' => { 'value' => 'test' } }, context.client_context)
  end

  def test_w3c_returns_baggage_only
    context = build_context({ 'w3c' => { 'baggage' => 'userId=alice' } })
    assert_equal({ 'baggage' => 'userId=alice' }, context.w3c)
  end

  def test_w3c_returns_every_allowlisted_field
    context = build_context(
      'custom' => { 'value' => 'test' },
      'w3c' => {
        'traceparent' => '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
        'tracestate' => 'rojo=00f067aa0ba902b7',
        'baggage' => 'userId=alice'
      }
    )
    assert_equal(
      {
        'traceparent' => '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01',
        'tracestate' => 'rojo=00f067aa0ba902b7',
        'baggage' => 'userId=alice'
      },
      context.w3c
    )
  end

  def test_w3c_is_stripped_from_client_context_but_siblings_are_kept
    context = build_context(
      'custom' => { 'value' => 'test' },
      'w3c' => { 'baggage' => 'userId=alice' }
    )
    refute context.client_context.key?('w3c')
    assert_equal({ 'custom' => { 'value' => 'test' } }, context.client_context)
  end

  def test_w3c_drops_non_string_values_and_non_allowlisted_keys
    context = build_context(
      'w3c' => {
        'baggage' => 'keep=me',
        'traceparent' => 42,
        'tracestate' => nil,
        'unknownField' => 'should-not-appear'
      }
    )
    assert_equal({ 'baggage' => 'keep=me' }, context.w3c)
  end

  def test_w3c_treats_non_hash_values_as_empty
    assert_equal({}, build_context('w3c' => 'not-an-object').w3c)
    assert_equal({}, build_context('w3c' => ['baggage=abc']).w3c)
  end

  def test_w3c_returns_a_fresh_copy_each_call
    context = build_context({ 'w3c' => { 'baggage' => 'userId=alice' } })
    first = context.w3c
    first['baggage'] = 'tampered'
    first['injected'] = 'nope'
    assert_equal({ 'baggage' => 'userId=alice' }, context.w3c)
  end
end
