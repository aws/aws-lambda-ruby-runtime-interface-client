# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

require 'stringio'

def ping(event:, context:)
  resp = {}
  if event.nil?
    resp[:event_nil] = true
  else
    resp[:msg] = "pong[#{event["msg"]}]"
  end
  puts "Hello, loggers!"
  resp
end

def str_ping(event:, context:)
  { msg: "pong[#{event}]" }
end

def broken(_)
  raise ArgumentError.new("My error message.")
end

def string(event:, context:)
  "Message: '#{event["msg"]}'"
end

def curl(event:,context:)
  resp = Net::HTTP.get(URI(event["url"]))
  if resp.size > 0
    { success: true }
  else
    raise "Empty response!"
  end
end

def io(_)
  StringIO.new("This is IO!")
end

def execution_env(_)
  { "AWS_EXECUTION_ENV" => ENV["AWS_EXECUTION_ENV"] }
end

class HandlerClass
  def self.ping(event:,context:)
    "Module Message: '#{event["msg"]}'"
  end
end

module DeepModule
  class Handler
    def self.ping(event:,context:)
      "Deep Module Message: '#{event["msg"]}'"
    end
  end
end
