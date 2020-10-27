# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true
module LambdaErrors

  class LambdaErrors::InvocationError < StandardError;
  end

  class LambdaError < StandardError
    def initialize(original_error, classification = 'Function')
      @error_class = original_error.class.to_s
      @error_type = "#{classification}<#{original_error.class}>"
      @error_message = original_error.message
      @stack_trace = _sanitize_stacktrace(original_error.backtrace_locations)
      super(original_error)
    end

    def runtime_error_type
      if _allowed_error?
        @error_type
      else
        'Function<UserException>'
      end
    end

    def to_lambda_response
      {
          :errorMessage => @error_message,
          :errorType => @error_type,
          :stackTrace => @stack_trace
      }
    end

    private

    def _sanitize_stacktrace(stacktrace)
      ret = []
      safe_trace = true
      if stacktrace
        stacktrace.first(100).each do |line|
          if safe_trace
            if line.to_s.match(%r{^lib})
              safe_trace = false
            else
              ret << line
            end
          end # else skip
        end
      end
      ret
    end

    def _allowed_error?
      # _aws_sdk_pattern? || _standard_error?
      _standard_error?
    end

    # Currently unused, may be activated later.
    def _aws_sdk_pattern?
      @error_class.match(/Aws(::\w+)*::Errors/)
    end

    def _standard_error?
      %w[ArgumentError NoMethodError Exception StandardError NameError LoadError SystemExit SystemStackError].include?(@error_class)
    end
  end

  class LambdaHandlerError < LambdaError
  end

  class LambdaHandlerCriticalException < LambdaError
  end

  class LambdaRuntimeError < LambdaError
    def initialize(original_error)
      super(original_error, 'Runtime')
    end
  end

  class LambdaRuntimeInitError < LambdaError
    def initialize(original_error)
      super(original_error, 'Init')
    end
  end
end
