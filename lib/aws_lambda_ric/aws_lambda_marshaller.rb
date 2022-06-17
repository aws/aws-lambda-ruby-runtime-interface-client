# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require 'stringio'

module AwsLambda
  class Marshaller
    class << self
      # By default, JSON-parses the raw request body. This can be overwritten
      # by users who know what they are doing.
      def marshall_request(raw_request)
        content_type = raw_request['Content-Type']
        if content_type == 'application/json'
          JSON.parse(raw_request.body)
        else
          raw_request.body # return it unaltered
        end
      end

      # By default, just runs #to_json on the method's response value.
      # This can be overwritten by users who know what they are doing.
      # The response is an array of response, content-type.
      # If returned without a content-type, it is assumed to be application/json
      # Finally, StringIO/IO is used to signal a response that shouldn't be
      # formatted as JSON, and should get a different content-type header.
      def marshall_response(method_response)
        case method_response
        when StringIO, IO
          [method_response, 'application/unknown']
        else
          method_response.to_json # application/json is assumed
        end
      end
    end
  end
end
