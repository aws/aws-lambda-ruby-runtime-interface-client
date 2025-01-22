# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

module LoggerPatch
  def initialize(logdev, shift_age = 0, shift_size = 1048576, level: 'debug',
                 progname: nil, formatter: nil, datetime_format: nil,
                 binmode: false, shift_period_suffix: '%Y%m%d')
    #  use unpatched constructor if logdev is a filename or an IO Object other than $stdout or $stderr
    if logdev && logdev != $stdout && logdev != $stderr
      super(logdev, shift_age, shift_size, level: level, progname: progname,
                      formatter: formatter, datetime_format: datetime_format,
                      binmode: binmode, shift_period_suffix: shift_period_suffix)
    else
      self.level = level
      self.progname = progname
      @default_formatter = LogFormatter.new
      self.datetime_format = datetime_format
      self.formatter = formatter
      @logdev = AwsLambdaRIC::TelemetryLogger.telemetry_log_sink
      @level_override = {}
    end
  end
end
