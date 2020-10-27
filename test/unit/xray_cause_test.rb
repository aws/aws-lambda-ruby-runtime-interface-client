# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/xray_cause'
require_relative '../../lib/aws_lambda_ric/lambda_errors'
require 'minitest/autorun'
require 'test/unit'

include Test::Unit::Assertions

class XRayCauseTest < Minitest::Test
  def test_xray_cause
    msg = "Unit testing is what I am doing when I don't know what I am doing"

    begin
      raise StandardError.new(msg)
    rescue StandardError => e
      under_test = XRayCause.new(LambdaErrors::LambdaError.new(e).to_lambda_response)
    end

    assert_equal Dir.pwd, under_test.instance_variable_get(:@cause)[:working_directory]
    assert_equal Gem.paths.path, under_test.instance_variable_get(:@cause)[:paths]
    assert_equal 1, under_test.instance_variable_get(:@cause)[:exceptions].count
    assert_equal msg, under_test.instance_variable_get(:@cause)[:exceptions][0][:message]
    assert_equal 'Function<StandardError>', under_test.instance_variable_get(:@cause)[:exceptions][0][:type]
    assert_true under_test.instance_variable_get(:@cause)[:exceptions][0][:stack].count.positive?
    assert_equal __FILE__, under_test.instance_variable_get(:@cause)[:exceptions][0][:stack][0][:path]
    assert_kind_of Integer, under_test.instance_variable_get(:@cause)[:exceptions][0][:stack][0][:line]
    assert_equal __method__.to_s, under_test.instance_variable_get(:@cause)[:exceptions][0][:stack][0][:label]
  end

  def test_stack_depth_maximum
    msg = 'All code is guilty, until proven innocent'
    begin
      raise_lambda_err_with_deep_trace(XRayCause::MAX_DEPTH + 1, StandardError.new(msg))
    rescue LambdaErrors::LambdaError => e
      under_test = XRayCause.new(e.to_lambda_response)
    end

    assert_equal 1, under_test.instance_variable_get(:@cause)[:exceptions].count
    assert_equal msg, under_test.instance_variable_get(:@cause)[:exceptions][0][:message]
    assert_equal XRayCause::MAX_DEPTH, under_test.instance_variable_get(:@cause)[:exceptions][0][:stack].count
  end

  def raise_lambda_err_with_deep_trace(depth, exc)
    unless depth.positive?
      raise LambdaErrors::LambdaError.new(exc)
    end
    raise LambdaErrors::LambdaRuntimeError.new(exc)
  rescue LambdaErrors::LambdaRuntimeError => e
    raise_lambda_err_with_deep_trace(depth - 1, e)
  end
end
