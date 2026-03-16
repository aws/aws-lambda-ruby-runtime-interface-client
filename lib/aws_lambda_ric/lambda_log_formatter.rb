# frozen_string_literal: true

require 'json'
require 'logger'

class LogFormatter < Logger::Formatter
  FORMAT = '%<sev>s, [%<datetime>s #%<process>d] %<severity>5s %<request_id>s -- %<progname>s: %<msg>s'

  def call(severity, time, progname, msg)
    formatted = FORMAT % {
      sev: severity[0..0],
      datetime: format_datetime(time),
      process: $$,
      severity: severity,
      request_id: $_global_aws_request_id,
      progname: progname,
      msg: msg2str(msg)
    }
    "#{formatted.encode('UTF-8', invalid: :replace, undef: :replace, replace: '�')}\n"
  end
end

class JsonLogFormatter < Logger::Formatter
  DATETIME_FORMAT = '%Y-%m-%dT%H:%M:%S.%6NZ'

  def call(severity, time, progname, msg)
    payload = {
      timestamp: time.utc.strftime(DATETIME_FORMAT),
      level: severity,
      message: message_for(msg),
      requestId: $_global_aws_request_id
    }

    logger_name = sanitize_utf8(progname) unless progname.nil?
    payload[:logger] = logger_name unless logger_name.nil? || logger_name.empty?

    if msg.is_a?(Exception)
      payload[:errorType] = msg.class.to_s
      payload[:errorMessage] = sanitize_utf8(msg.message)
      payload[:stackTrace] = Array(msg.backtrace).map { |line| sanitize_utf8(line) }
      location = location_for(msg)
      payload[:location] = location unless location.nil?
    end

    "#{JSON.generate(payload.compact)}\n"
  end

  private

  def message_for(msg)
    result = msg.is_a?(Exception) ? msg.message : msg2str(msg)
    sanitize_utf8(result)
  end

  def location_for(exception)
    first_backtrace_line = exception.backtrace&.first
    return nil if first_backtrace_line.nil?

    sanitized_line = sanitize_utf8(first_backtrace_line)
    matched = sanitized_line.match(/\A(?<file>.+):(?<line>\d+):in [`'](?<method>.+)'\z/)
    return "#{matched[:file]}:#{matched[:method]}:#{matched[:line]}" if matched

    sanitized_line
  end

  def sanitize_utf8(value)
    value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '�')
  end
end
