# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

class LambdaLogger
  class << self
    def log_error(exception:, message: nil)
      puts message if message
      puts JSON.pretty_unparse(exception.to_lambda_response)
    end
  end
end
