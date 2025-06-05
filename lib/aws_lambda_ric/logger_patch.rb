# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

module LoggerPatch
  def initialize(logdev, shift_age = 0, shift_size = 1048576, level: 'debug',
                 progname: nil, formatter: nil, datetime_format: nil,
                 binmode: false, shift_period_suffix: '%Y%m%d')
    logdev_lambda_override = logdev
    formatter_override = formatter
    # use unpatched constructor if logdev is a filename or an IO Object other than $stdout or $stderr
    if !logdev || logdev == $stdout || logdev == $stderr
      logdev_lambda_override = AwsLambdaRIC::TelemetryLogger.telemetry_log_sink
      formatter_override = formatter_override || LogFormatter.new
    end

    super(logdev_lambda_override, shift_age, shift_size, level: level, progname: progname,
                                    formatter: formatter_override, datetime_format: datetime_format,
                                    binmode: binmode, shift_period_suffix: shift_period_suffix)
  end
end
