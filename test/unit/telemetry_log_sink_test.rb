# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/telemetry_log_sink'
require 'tempfile'
require 'minitest/autorun'
require 'test/unit/assertions'
require 'time'

include Test::Unit::Assertions

class TelemetryLogSinkTest < Minitest::Test

  def test_single_frame
    log = "Single frame\n even if there are multiple lines\nthird line"
    Tempfile.create do |file|
      start = (Time.new.to_f*1000000).to_i
      under_test = TelemetryLogSink.new(file: file)

      under_test.write(log)
      file.rewind

      finish = (Time.new.to_f*1000000).to_i

      until file.eof?
        frame = file.read(4).unpack('L>')[0]
        assert_equal 0xa55a0003, frame

        length = file.read(4).unpack('L>')[0]
        assert_equal log.bytesize, length

        timestamp = file.read(8).unpack('Q>')[0]
        assert timestamp >= start, "Timestamp smaller than start time"
        assert timestamp <= finish, "Timestamp greater than finish time"

        content = file.read(length)
        assert_equal log, content
      end
    end
  end

  def test_multiple_frames
    log_messages = ["First message first line\n second line", "Second message first line\n second line"]
    Tempfile.create do |file|
      start = (Time.new.to_f*1000000).to_i

      under_test = TelemetryLogSink.new(file: file)

      log_messages.each { |log| under_test.write(log) }
      file.rewind

      finish = (Time.new.to_f*1000000).to_i

      log_messages.each do |log|
        frame = file.read(4).unpack('L>')[0]
        assert_equal 0xa55a0003, frame

        length = file.read(4).unpack('L>')[0]
        assert_equal log.bytesize, length

        timestamp = file.read(8).unpack('Q>')[0]
        assert timestamp >= start, "Timestamp smaller than start time"
        assert timestamp <= finish, "Timestamp greater than finish time"

        content = file.read(length)
        assert_equal log, content
      end
      assert_true file.eof?
    end
  end
end
