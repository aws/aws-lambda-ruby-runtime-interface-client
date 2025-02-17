# frozen_string_literal: true

require_relative 'lambda_errors'

class XRayCause
  MAX_DEPTH = 15

  def initialize(lambda_error)
    @cause = {
      working_directory: Dir.pwd,
      paths: Gem.paths.path,
      exceptions: lambda_error ? normalize(err: lambda_error) : lambda_error
    }
  end

  def as_json
    @as_json ||= begin
                   JSON.dump(@cause)
                 end
  end

  private

  def normalize(err:)
    exception = {
      message: err[:errorMessage],
      type: err[:errorType]
    }

    backtrace = err[:stackTrace]
    if backtrace
      exception[:stack] = backtrace.first(MAX_DEPTH).collect do |t|
        {
          path: t.path,
          line: t.lineno,
          label: t.label
        }
      end
    end
    [exception]
  end
end