# encoding: binary

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers/runtime/field'

describe ProtocolBuffers, "fields" do

  before(:each) do
  # clear our namespaces
    Object.send(:remove_const, :Featureful) if Object.const_defined?(:Featureful)
  # load test proto
    load File.join(File.dirname(__FILE__), "proto_files", "featureful.pb.rb")
  end

  def mkfield(ftype)
    ProtocolBuffers::Field.const_get(ftype).new(:optional, "test", 1)
  end

  it "checks bounds on varint field types" do
    u32 = mkfield(:Uint32Field)
    expect { u32.check_valid(0xFFFFFFFF) }.not_to raise_error()
    expect { u32.check_valid(0x100000000) }.to raise_error(ArgumentError)
    expect { u32.check_valid(-1) }.to raise_error(ArgumentError)

    u64 = mkfield(:Uint64Field)
    expect { u64.check_valid(0xFFFFFFFF_FFFFFFFF) }.not_to raise_error()
    expect { u64.check_valid(0x100000000_00000000) }.to raise_error(ArgumentError)
    expect { u64.check_valid(-1) }.to raise_error(ArgumentError)
  end

  it "properly encodes and decodes negative varints" do
    val = -2082844800000000
    str = "\200\300\313\274\236\265\246\374\377\001"
    sio = ProtocolBuffers.bin_sio
    ProtocolBuffers::Varint.encode(sio, val)
    expect(sio.string).to eq(str)
    sio.rewind
    val2 = ProtocolBuffers::Varint.decode(sio)
    int64 = mkfield(:Int64Field)
    expect(int64.deserialize(val2)).to eq(val)
    expect { int64.check_value(int64.deserialize(val2)) }.not_to raise_error
  end

  context "UTF-8 encoding of length-delimited fields" do
    if RUBY_VERSION < "1.9"
      pending "UTF-8 validation only happens in ruby 1.9+"
    else

      before :each do
        @good_utf   = "\xc2\xa1hola\x21"
        @bad_utf    = "\xc2"
        @good_ascii = "!hola!".force_encoding("us-ascii")

        @good_utf_io   = proc { StringIO.new(@good_utf) }
        @bad_utf_io    = proc { StringIO.new(@bad_utf) }
        @good_ascii_io = proc { StringIO.new(@good_ascii) }

        @s = mkfield(:StringField)
        @b = mkfield(:BytesField)
      end

      context "string fields" do

        it "forces UTF-8 on serializing" do
          expect(@s.serialize(@good_utf).encoding).to eq(Encoding::UTF_8)
          expect { @s.check_valid(@s.serialize(@good_utf)) }.not_to raise_error()

          expect(@s.serialize(@good_ascii).encoding).to eq(Encoding::UTF_8)
          expect { @s.check_valid(@s.serialize(@good_ascii)) }.not_to raise_error()

          expect { @s.serialize(@bad_utf) }.to raise_error(ArgumentError)
        end

        it "forces UTF-8 on deserializing" do
          expect(@s.deserialize(@good_utf_io[]).encoding).to eq(Encoding::UTF_8)
          expect { @s.check_valid(@s.deserialize(@good_utf_io[])) }.not_to raise_error()

          expect(@s.deserialize(@good_ascii_io[]).encoding).to eq(Encoding::UTF_8)
          expect { @s.check_valid(@s.deserialize(@good_ascii_io[])) }.not_to raise_error()

          expect(@s.deserialize(@bad_utf_io[]).encoding).to eq(Encoding::UTF_8)
          expect { @s.check_valid(@s.deserialize(@bad_utf_io[])) }.to raise_error(ArgumentError)
        end
      end

      context "byte fields" do

        it "does not force UTF-8 on deserializing" do
          expect(@b.deserialize(@good_utf_io[]).encoding).to eq(Encoding::BINARY)
          expect { @b.check_valid(@b.deserialize(@good_utf_io[])) }.not_to raise_error()

          expect(@b.deserialize(@good_ascii_io[]).encoding).to eq(Encoding.find("us-ascii"))
          expect { @b.check_valid(@b.deserialize(@good_ascii_io[])) }.not_to raise_error()

          expect(@b.deserialize(@bad_utf_io[]).encoding).to eq(Encoding::BINARY)
          expect { @b.check_valid(@b.deserialize(@bad_utf_io[])) }.not_to raise_error()
        end
      end
    end
  end

  it "provides a reader for proxy_class on message fields" do
    expect(ProtocolBuffers::Field::MessageField.new(nil, :optional, :fake_name, 1)).to respond_to(:proxy_class)
    expect(ProtocolBuffers::Field::MessageField.new(Class, :optional, :fake_name, 1).proxy_class).to eq(Class)
  end

  it "allows one to check if a default has been set in the protobuff without setting it in ruby" do
    bit = Featureful::ABitOfEverything.new
    fields_with_defaults = [:int64_field, :bool_field, :string_field]
    bit.fields.values.each do |field|
      fields_with_defaults.include?(field.name) ? expect(field).to(have_default) : expect(field).not_to(have_default)
    end
  end
end
