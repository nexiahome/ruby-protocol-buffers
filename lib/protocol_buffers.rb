require 'stringio'

if RUBY_VERSION < "1.9"
  raise("This version of ruby-protocol-buffers no longer supports Ruby 1.8.7")
end

module ProtocolBuffers
  def self.bin_sio(*args)
    sio = StringIO.new(*args)
    sio.set_encoding(Encoding::BINARY) if
      sio.respond_to?(:set_encoding) and
      sio.external_encoding != Encoding::BINARY
    sio
  end

  def self.utf8_sio(*args)
    sio = StringIO.new(*args)
    sio.set_encoding('utf-8') if
      sio.respond_to?(:set_encoding) and
      sio.external_encoding != Encoding::UTF_8
    sio
  end
end

# $LOAD_PATH << File.dirname(__FILE__)

require 'protocol_buffers/version'
require 'protocol_buffers/runtime/message'
require 'protocol_buffers/runtime/enum'
require 'protocol_buffers/runtime/service'
