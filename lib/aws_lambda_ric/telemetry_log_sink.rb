# frozen_string_literal: true

require 'logger'
require 'time'

class TelemetryLogSink < Logger::LogDevice

  # TelemetryLogSink implements the logging contract between runtimes and the platform. It implements a simple
  # framing protocol so message boundaries can be determined. Each frame can be visualized as follows:
  #
  # +----------------------+------------------------+---------------------+-------------------------+
  # | Frame Type - 4 bytes | Length (len) - 4 bytes | Timestamp - 8 bytes | Message - \'len\' bytes |
  # +----------------------+------------------------+---------------------+-------------------------+
  #
  # The first 4 bytes indicate the type of the frame - log frames have a type defined as the hex value 0xa55a0003. The
  # second 4 bytes should indicate the message\'s length. Next, the timestamp in microsecond precision, and finally
  # \'len\' bytes contain the message. The byte order is big-endian.

  def initialize(file:)
    @file = file
  end

  FRAME_BYTES = [0xa55a0003].pack('L>')

  def write(msg)
    @semaphore ||= Mutex.new
    if @file.nil? || @file.closed?
      $stdout.write(msg)
    else
      @semaphore.synchronize do
        @file.write(FRAME_BYTES)
        @file.write([msg.bytesize].pack('L>'))
        @file.write([(Time.new.to_f*1000000).to_i].pack('Q>'))
        @file.write(msg)
      end
    end
  end

  def reopen(log = nil)
    # do nothing
  end

  def close
    # do nothing
  end
end
