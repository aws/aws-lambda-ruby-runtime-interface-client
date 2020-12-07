# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

def put_message(event:, context:)
  puts(event['messages'])
  'ok'
end

def put_frozen_string(event:, context:)
  puts(event['messages'].freeze)
  'ok'
end

def put_messages_and_read_fd(event:, context:)
  event['messages'].each { |m| puts(m) }
  content = ''
  read_fd(content, event)
end

require 'logger'

def log_to_stdout_and_read_fd(event:, context:)
  logger = Logger.new($stdout)
  event['messages'].each { |m| logger.info(m) }
  read_fd('', event)
end

def log_to_stderr_and_read_fd(event:, context:)
  logger = Logger.new($stderr)
  event['messages'].each { |m| logger.error(m) }
  read_fd('', event)
end

def log_to_file_and_read_back(event:, context:)
  logger = Logger.new(event['file_path'])
  event['messages'].each { |m| logger.info(m) }
  read_file('', event)
end

def read_file(content, event)
  File.foreach(event['file_path']) { |line| content << line }
  content
end

def read_fd(content, event)
  File.open(event['fd_path'], 'rb') do |file|
    until file.eof?
      frame_type = file.read(4).unpack('L>')[0]
      content << frame_type.to_s
      length = file.read(4).unpack('L>')[0]
      content << length.to_s
      log = file.read(length)
      content << log
    end
  end
  content
end
