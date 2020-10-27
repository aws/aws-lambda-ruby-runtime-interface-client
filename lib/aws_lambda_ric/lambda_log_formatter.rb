# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require 'logger'

class LambdaLogFormatter < Logger::Formatter
  FORMAT = '%<sev>s, [%<datetime>s#%<process>d] %<severity>5s %<request_id>s -- %<progname>s: %<msg>s'

  def call(severity, time, progname, msg)
    (FORMAT % {sev: severity[0..0], datetime: format_datetime(time), process: $$, severity: severity,
               request_id: $_global_aws_request_id, progname: progname, msg: msg2str(msg)}).encode!('UTF-8')
  end
end
