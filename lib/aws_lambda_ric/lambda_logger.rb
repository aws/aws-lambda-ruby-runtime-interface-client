# frozen_string_literal: true

class LambdaLogger
  class << self
    def log_error(exception:, message: nil)
      puts message if message
      puts JSON.pretty_generate(exception.to_lambda_response)
    end
  end
end
