# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/telemetry_log_sink'
require 'tempfile'
require 'minitest/autorun'
require 'test/unit/assertions'

include Test::Unit::Assertions

class TelemetryLogSinkTest < Minitest::Test

  def test_single_frame
    log = "Single frame\n even if there are multiple lines\nthird line"
    Tempfile.create do |file|
      under_test = TelemetryLogSink.new(file: file)

      under_test.write(log)
      file.rewind

      until file.eof?
        frame = file.read(4).unpack1('L>')
        assert_equal 0xa55a0001, frame

        length = file.read(4).unpack1('L>')
        assert_equal log.bytesize, length

        content = file.read(length)
        assert_equal log, content
      end
    end
  end

  def test_multiple_frames
    log_messages = ["First message first line\n second line", "Second message first line\n second line"]
    Tempfile.create do |file|
      under_test = TelemetryLogSink.new(file: file)

      log_messages.each { |log| under_test.write(log) }
      file.rewind

      log_messages.each do |log|
        frame = file.read(4).unpack1('L>')
        assert_equal 0xa55a0001, frame

        length = file.read(4).unpack1('L>')
        assert_equal log.bytesize, length

        content = file.read(length)
        assert_equal log, content
      end
      assert_true file.eof?
    end
  end
end
