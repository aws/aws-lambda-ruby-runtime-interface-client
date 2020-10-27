# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.

def test_wrapper_executed(event:, context:)
  File.open(File.expand_path('../', __FILE__) + '/hi_there') do |file|
    return file.read
  end
end
