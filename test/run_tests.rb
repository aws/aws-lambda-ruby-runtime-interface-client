# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# run tests in specified directory and its sub-directories
if ARGV.length != 1
  puts 'We need exactly one argument, the directory name containing tests to run.'
  exit
end

test_directory = File.join(File.dirname(File.absolute_path(__FILE__)), ARGV[0])
Dir["#{test_directory}/**/*_test.rb"].each { |file| require_relative file }
