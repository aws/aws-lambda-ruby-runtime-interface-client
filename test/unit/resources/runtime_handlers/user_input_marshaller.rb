# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

module AwsLambda
  class Marshaller
    def self.marshall_request(raw)
      event = JSON.parse(raw.body)
      event['squared'] = event['numbers'].map do |n|
        n * n
      end
      event
    end
  end
end

def squared_input(event:,context:)
  event['squared']
end
