# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

module AwsLambda
  class Marshaller
    def self.marshall_response(resp)
      {
        body: resp,
        metadata: "Marshaller brought to you by Test Harness Industries."
      }.to_json
    end
  end
end

def add_metadata(_)
  "Simple response."
end
