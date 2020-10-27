# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.

# frozen_string_literal: true

require 'logger'

class TelemetryLogSink < Logger::LogDevice

  # TelemetryLogSink implements the logging contract between runtimes and the platform. It implements a simple
  # framing protocol so message boundaries can be determined. Each frame can be visualized as follows:
  #
  # +----------------------+------------------------+-----------------------+
  # | Frame Type - 4 bytes | Length (len) - 4 bytes | Message - \'len\' bytes |
  # +----------------------+------------------------+-----------------------+
  #
  # The first 4 bytes indicate the type of the frame - log frames have a type defined as the hex value 0xa55a0001. The
  # second 4 bytes should indicate the message\'s length. The next \'len\' bytes contain the message. The byte order is
  # big-endian.

  def initialize(file:)
    @file = file
  end

  FRAME_BYTES = [0xa55a0001].pack('L>')

  def write(msg)
    if @file.nil? || @file.closed?
      $stdout.write(msg)
    else
      @file.write(FRAME_BYTES)
      @file.write([msg.bytesize].pack('L>'))
      @file.write(msg)
    end
  end

  def reopen(log = nil)
    # do nothing
  end

  def close
    # do nothing
  end
end
