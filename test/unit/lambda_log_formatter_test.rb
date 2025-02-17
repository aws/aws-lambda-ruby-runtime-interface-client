# frozen_string_literal: true

require_relative '../../lib/aws_lambda_ric/lambda_log_formatter'
require 'logger'
require 'securerandom'
require 'minitest/autorun'

class LambdaLogFormatterTest < Minitest::Test

  def test_formatter
    $_global_aws_request_id = SecureRandom.uuid
    time = Time.now
    progname = 'test_progname'
    msg = 'log_message'
    under_test = LogFormatter.new

    actual = under_test.call('INFO', time, progname, msg)

    assert_equal "I, [#{time.strftime("%Y-%m-%dT%H:%M:%S.%6N")} ##{$$}]  INFO #{$_global_aws_request_id} -- #{progname}: #{msg}", actual
  end
end