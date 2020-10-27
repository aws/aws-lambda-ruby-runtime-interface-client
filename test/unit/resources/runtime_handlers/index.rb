# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

require 'json'

def get_suite(event:, context:)
  file_name = event + '.json'
  file = File.read(file_name)
  return JSON.parse(file)
end
