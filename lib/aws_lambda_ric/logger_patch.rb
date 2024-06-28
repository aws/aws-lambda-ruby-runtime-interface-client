# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

module LoggerPatch
  def initialize(logdev, shift_age = 0, shift_size = 1048576, level: 'debug',
                 progname: nil, formatter: nil, datetime_format: nil,
                 binmode: false, shift_period_suffix: '%Y%m%d')
    logdev_lambda_overwrite = logdev
    # use unpatched constructor if logdev is a filename or an IO Object other than $stdout or $stderr
    if !logdev || logdev == $stdout || logdev == $stderr
      logdev_lambda_overwrite = AwsLambdaRuntimeInterfaceClient::TelemetryLoggingHelper.telemetry_log_sink
      @default_formatter = LambdaLogFormatter.new
    end

    super(logdev_lambda_overwrite, shift_age, shift_size, level: level, progname: progname,
                                    formatter: formatter, datetime_format: datetime_format,
                                    binmode: binmode, shift_period_suffix: shift_period_suffix)
  end
end
