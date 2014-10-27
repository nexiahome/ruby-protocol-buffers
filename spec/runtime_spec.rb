# encoding: binary

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

describe ProtocolBuffers, "runtime" do
  before(:each) do
    # clear our namespaces
    %w( Simple Featureful Foo Packed TehUnknown TehUnknown2 TehUnknown3 Enums A C Services).each do |klass|
      Object.send(:remove_const, klass.to_sym) if Object.const_defined?(klass.to_sym)
    end

    # load test protos
    %w( simple featureful packed enums no_package services).each do |proto|
      load File.join(File.dirname(__FILE__), "proto_files", "#{proto}.pb.rb")
    end
  end

  context "packed field handling" do

    before :each do
      @packed = Packed::Test.new
    end

    it "does not encode empty field" do
      @packed.a = [ ]
      expect(@packed.to_s).to eq("")

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)
      expect(unpacked.a).to eq([ ])
    end

    it "correctly encodes repeated field" do
      # Example values from https://developers.google.com/protocol-buffers/docs/encoding.
      @packed.a  = [ 3, 270 ]
      @packed.a << 86942
      # this is a ruby 2 string encoding issue
      # it correctly unpacks to the expected though
      # expect(@packed.to_s).to eq("\x22\x06\x03\x8e\x02\x9e\xa7\x05")

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)
      expect(unpacked.a).to eq([ 3, 270, 86942 ])
    end

    it "handles primitive numeric data types" do
      types_to_be_packed = {
        :int32    => { :field => :a, :value => [ 0, 1, 1 ] },
        :int64    => { :field => :b, :value => [ 2, 3, 5 ] },

        :uint32   => { :field => :c, :value => [ 8, 13, 21 ] },
        :uint64   => { :field => :d, :value => [ 34, 55, 89 ] },

        :sint32   => { :field => :e, :value => [ -114, 233, -377 ] },
        :sint64   => { :field => :f, :value => [ 610, -987, 1597 ] },

        :fixed64  => { :field => :g, :value => [ 2584, 4181, 6765 ] },
        :sfixed64 => { :field => :h, :value => [ -10946, 17711, -28657 ] },
        :double   => { :field => :i, :value => [ 46.368, -75025, 121.393 ] },

        :fixed32  => { :field => :j, :value => [ 196418, 317811, 514229 ] },
        :sfixed32 => { :field => :k, :value => [ -832040, 1346269, -2178309 ] },
        :float    => { :field => :l, :value => [ 3524.578, -5702887, 92274.65 ] },

        :bool     => { :field => :m, :value => [ false, false, true, false ] },
        :enum     => { :field => :n, :value => [ Packed::Test::N::A, Packed::Test::N::B, Packed::Test::N::A, Packed::Test::N::C ] }
      }

      types_to_be_packed.values.each do |v|
        @packed.send("#{v[:field]}=", v[:value])
      end

      ser = ProtocolBuffers.bin_sio(@packed.to_s)
      unpacked = Packed::Test.parse(ser)

      types_to_be_packed.each_pair do |k, v|
        if [ :float, :double ].include? k
          act = unpacked.send(v[:field]).map{|i| (i * 100).round}
          exp = v[:value].map{|i| (i * 100).round}

          expect(act).to eq(exp)
        else
          expect(unpacked.send(v[:field])).to eq(v[:value])
        end
      end

    end

  end

  it "can handle basic operations" do

    msg1 = Simple::Test1.new
    expect(msg1.test_field).to eq("")

    msg1.test_field = "zomgkittenz"

    ser = ProtocolBuffers.bin_sio(msg1.to_s)
    msg2 = Simple::Test1.parse(ser)
    expect(msg2.test_field).to eq("zomgkittenz")
    expect(msg2).to eq(msg1)
  end

  it "correctly unsets fields" do
    msg1 = Simple::Test1.new
    expect(msg1.has_test_field?).to eq(false)
    expect(msg1.test_field).to eq("")
    expect(msg1.to_s).to eq("")

    msg1.test_field = "zomgkittenz"
    expect(msg1.has_test_field?).to eq(true)
    expect(msg1.test_field).to eq("zomgkittenz")
    expect(msg1.to_s).not_to eq("")

    msg1.test_field = nil
    expect(msg1.has_test_field?).to eq(false)
    expect(msg1.test_field).to eq("")
    expect(msg1.to_s).to eq("")
  end

  it "doesn't serialize unset fields" do
    msg1 = Simple::Test1.new
    expect(msg1.has_test_field?).to eq(false)
    expect(msg1.test_field).to eq("")
    expect(msg1.to_s).to eq("")

    msg2 = Simple::Test1.parse(ProtocolBuffers.bin_sio(msg1.to_s))
    expect(msg2.has_test_field?).to eq(false)
    expect(msg2.test_field).to eq("")
    expect(msg2.to_s).to eq("")

    msg1 = Simple::Test1.new
    expect(msg1.has_test_field?).to eq(false)
    expect(msg1.test_field).to eq("")
    expect(msg1.to_s).to eq("")

    msg1.test_field = "zomgkittenz"
    expect(msg1.to_s).not_to eq("")

    msg1.test_field = nil

    msg2 = Simple::Test1.parse(ProtocolBuffers.bin_sio(msg1.to_s))
    expect(msg2.has_test_field?).to eq(false)
    expect(msg2.test_field).to eq("")
    expect(msg2.to_s).to eq("")
  end

  it "flags values that have been set" do
    a1 = Featureful::A.new
    expect(a1.has_i2?).to eq(false)
    a1.i2 = 5
    expect(a1.has_i2?).to eq(true)
  end

  it "flags sub-messages that have been set" do
    a1 = Featureful::A.new
    expect(a1.value_for_tag?(a1.class.field_for_name(:sub1).tag)).to eq(true)
    expect(a1.value_for_tag?(a1.class.field_for_name(:sub2).tag)).to eq(false)
    expect(a1.value_for_tag?(a1.class.field_for_name(:sub3).tag)).to eq(false)

    expect(a1.has_sub1?).to eq(true)
    expect(a1.has_sub2?).to eq(false)
    expect(a1.has_sub3?).to eq(false)

    a1.sub2 = Featureful::A::Sub.new(:payload => "ohai")
    expect(a1.has_sub2?).to eq(true)
  end

  it "flags group that have been set" do
    a1 = Featureful::A.new
    expect(a1.value_for_tag?(a1.class.field_for_name(:group1).tag)).to eq(true)
    expect(a1.value_for_tag?(a1.class.field_for_name(:group2).tag)).to eq(false)
    expect(a1.value_for_tag?(a1.class.field_for_name(:group3).tag)).to eq(false)

    expect(a1.has_group1?).to eq(true)
    expect(a1.has_group2?).to eq(false)
    expect(a1.has_group3?).to eq(false)

    a1.group2 = Featureful::A::Group2.new(:i1 => 1)
    expect(a1.has_group2?).to eq(true)
  end

  describe "#inspect" do
    it "should leave out un-set fields" do
      b1 = Simple::Bar.new
      expect(b1.inspect).to eq("#<Simple::Bar foo=<unset>>")
      b1.foo = Simple::Foo.new
      expect(b1.inspect).to eq("#<Simple::Bar foo=#<Simple::Foo>>")
    end
  end

  it "detects changes to a sub-message and flags it as set if it wasn't" do
    a1 = Featureful::A.new
    expect(a1.has_sub2?).to eq(false)
    a1.sub2.payload = "ohai"
    expect(a1.has_sub2?).to eq(true)

    expect(a1.has_group2?).to eq(false)
    a1.group2.i1 = 1
    expect(a1.has_sub2?).to eq(true)
  end

  it "detects changes to a sub-sub-message and flags up the chain" do
    a1 = Featureful::A.new
    expect(a1.sub2.has_subsub1?).to eq(false)
    expect(a1.has_sub2?).to eq(false)
    a1.sub2.subsub1.subsub_payload = "ohai"
    expect(a1.has_sub2?).to eq(true)
    expect(a1.sub2.has_subsub1?).to eq(true)
  end

  it "allows directly recursive sub-messages" do
    module Foo
      class Foo < ProtocolBuffers::Message
        optional :int32, :payload, 1
        optional Foo, :foo, 2
      end
    end

    foo = Foo::Foo.new
    expect(foo.has_foo?).to eq(false)
    foo.foo.payload = 17
    expect(foo.has_foo?).to eq(true)
    expect(foo.foo.has_foo?).to eq(false)
  end

  it "allows indirectly recursive sub-messages" do
    module Foo
      class Bar < ProtocolBuffers::Message; end

      class Foo < ProtocolBuffers::Message
        optional :int32, :payload, 1
        optional Bar, :bar, 2
      end

      class Bar
        optional Foo, :foo, 1
        optional :int32, :payload, 2
      end
    end

    foo = Foo::Foo.new
    expect(foo.has_bar?).to eq(false)
    foo.bar.payload = 17
    expect(foo.has_bar?).to eq(true)
    expect(foo.bar.has_foo?).to eq(false)
    foo.bar.foo.payload = 23
    expect(foo.bar.has_foo?).to eq(true)
  end

  it "pretends that repeated fields are arrays" do
    # make sure our RepeatedField class acts like a normal Array
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    foo2 = Foo::Foo.new(:nums => [1,2,3])
    expect do
      foo.nums << 1
      expect(foo.nums.class).to eq(ProtocolBuffers::RepeatedField)
      expect(foo.nums.to_a.class).to eq(Array)
      expect(foo.nums & foo2.nums).to eq([1])
      expect(foo.nums + foo2.nums).to eq([1,1,2,3])
      foo2.nums.map! { |i| i + 1 }
      expect(foo2.nums.to_a).to eq([2,3,4])
      expect(foo2.nums.class).to eq(ProtocolBuffers::RepeatedField)
    end.not_to raise_error
  end

  it "does type checking of repeated fields" do
    a1 = Featureful::A.new
    expect do
      a1.sub1 << Featureful::A::Sub.new
    end.not_to raise_error

    a1 = Featureful::A.new
    expect do
      a1.sub1 << Featureful::A::Sub.new << "dummy string"
    end.to raise_error(TypeError)
    expect(a1.sub1).to eq([Featureful::A::Sub.new])

    a1 = Featureful::A.new
    expect do
      a1.sub1 = [Featureful::A::Sub.new, Featureful::A::Sub.new, 5, Featureful::A::Sub.new]
    end.to raise_error(TypeError)
  end

  it "does value checking of repeated fields" do
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    expect do
      foo.nums << 5 << 3 << (1 << 32) # value too large for int32
    end.to raise_error(ArgumentError)
  end

  # sort of redundant test, but let's check the example in the docs for
  # correctness
  it "handles singular message fields exactly as in the documentation" do
    module Foo
      class Bar < ProtocolBuffers::Message
        optional :int32, :i, 1
      end
      class Foo < ProtocolBuffers::Message
        optional Bar, :bar, 1
      end
    end

    foo = Foo::Foo.new
    expect(foo.has_bar?).to eq(false)
    foo.bar = Foo::Bar.new
    expect(foo.has_bar?).to eq(true)

    foo = Foo::Foo.new
    expect(foo.has_bar?).to eq(false)
    foo.bar.i = 1
    expect(foo.has_bar?).to eq(true)

    foo = Foo::Foo.new
    expect(foo.has_bar?).to eq(false)
    _local_i = foo.bar.i
    expect(foo.has_bar?).to eq(false)
  end

  # another example from the docs
  it "handles repeated field logic" do
    module Foo
      class Foo < ProtocolBuffers::Message
        repeated :int32, :nums, 1
      end
    end

    foo = Foo::Foo.new
    expect(foo.has_nums?).to eq(true)
    foo.nums << 15
    expect(foo.has_nums?).to eq(true)
    foo.nums.push(32)
    expect(foo.nums.length).to eq(2)
    expect(foo.nums[0]).to eq(15)
    expect(foo.nums[1]).to eq(32)
    foo.nums[1] = 56
    expect(foo.nums[1]).to eq(56)

    foo = Foo::Foo.new
    foo.nums << 15
    foo.nums.push(32)
    expect(foo.nums.length).to eq(2)
    foo.nums.clear
    expect(foo.nums.length).to eq(0)
    foo.nums << 15
    expect(foo.nums.length).to eq(1)
    foo.nums = nil
    expect(foo.nums.length).to eq(0)

    foo = Foo::Foo.new
    foo.nums << 15
    foo.nums = [1, 3, 5]
    expect(foo.nums.length).to eq(3)
    expect(foo.nums.to_a).to eq([1,3,5])

    foo.merge_from_string(foo.to_s)
    expect(foo.nums.length).to eq(6)
    expect(foo.nums.to_a).to eq([1,3,5,1,3,5])
  end

  it "can assign any object with an each method to a repeated field" do
    module Foo
      class Bar < ProtocolBuffers::Message
        optional :int32, :i, 1
      end

      class Foo < ProtocolBuffers::Message
        repeated Bar, :nums, 1
      end
    end

    class Blah
      def each
        yield Foo::Bar.new(:i => 1)
        yield Foo::Bar.new(:i => 3)
      end
    end

    foo = Foo::Foo.new
    foo.nums = Blah.new
    expect(foo.nums.to_a).to eq([Foo::Bar.new(:i => 1), Foo::Bar.new(:i => 3)])
  end

  it "shouldn't modify the default Message instance like this" do
    a1 = Featureful::A.new
    a1.sub2.payload = "ohai"
    a2 = Featureful::A.new
    expect(a2.sub2.payload).to eq("")
    sub = Featureful::A::Sub.new
    expect(sub.payload).to eq("")
  end

  it "responds to gen_methods! for backwards compat" do
    Featureful::A.gen_methods!
  end

  def filled_in_bit
    bit = Featureful::ABitOfEverything.new
    expect(bit.int64_field).to eq(15)
    expect(bit.bool_field).to eq(false)
    expect(bit.string_field).to eq("zomgkittenz")
    bit.double_field = 1.0
    bit.float_field = 2.0
    bit.int32_field = 3
    bit.int64_field = 4
    bit.uint32_field = 5
    bit.uint64_field = 6
    bit.sint32_field = 7
    bit.sint64_field = 8
    bit.fixed32_field = 9
    bit.fixed64_field = 10
    bit.sfixed32_field = 11
    bit.sfixed64_field = 12
    bit.bool_field = true
    bit.string_field = "14"
    bit.bytes_field = "15"
    bit
  end

  it "can serialize and de-serialize all basic field types" do
    bit = filled_in_bit

    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    expect(bit).to eq(bit2)
    bit.fields.each do |tag, field|
      expect(bit.value_for_tag(tag)).to eq(bit2.value_for_tag(tag))
    end
  end

  it "does type checking" do
    bit = filled_in_bit

    expect do
      bit.fixed32_field = 1.0
    end.to raise_error(TypeError)

    expect do
      bit.double_field = 15
    end.not_to raise_error()
    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    expect(bit2.double_field).to eq(15)
    expect(bit2.double_field).to eq(15.0)
    expect(bit2.double_field.is_a?(Float)).to eq(true)

    expect do
      bit.bool_field = 1.0
    end.to raise_error(TypeError)

    expect do
      bit.string_field = 1.0
    end.to raise_error(TypeError)

    a1 = Featureful::A.new
    expect do
      a1.sub2 = "zomgkittenz"
    end.to raise_error(TypeError)
  end

  it "doesn't allow invalid enum values" do
    sub = Featureful::A::Sub.new

    expect do
      expect(sub.payload_type).to eq(0)
      sub.payload_type = Featureful::A::Sub::Payloads::P2
      expect(sub.payload_type).to eq(1)
    end.not_to raise_error()

    expect do
      sub.payload_type = 2
    end.to raise_error(ArgumentError)
  end

  it "enforces required fields on serialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        required :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')

    expect { res1.to_s }.to raise_error(ProtocolBuffers::EncodeError)

    begin
      res1.to_s
    rescue Exception => e
      expect(e.invalid_field.name).to eq(:field_1)
      expect(e.invalid_field.tag).to eq(1)
      expect(e.invalid_field.otype).to eq(:required)
      expect(e.invalid_field.default_value).to eq('')
    end

  end

  it "enforces required fields on deserialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')
    buf = res1.to_s

    # now make field_1 required
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        required :string, :field_1, 1
        optional :string, :field_2, 2
      end
    end

    expect { TehUnknown2::MyResult.parse(buf) }.to raise_error(ProtocolBuffers::DecodeError)
  end

  it "enforces valid values on deserialization" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :int64, :field_1, 1
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => (2**33))
    buf = res1.to_s

    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
      end
    end

    expect { TehUnknown2::MyResult.parse(buf) }.to raise_error(ProtocolBuffers::DecodeError)
  end

  it "ignores and passes on unknown fields" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_2, 2
        optional :int32, :field_3, 3
        optional :int32, :field_4, 4
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => 0xffff, :field_2 => 0xfffe,
                                   :field_3 => 0xfffd, :field_4 => 0xfffc)
    serialized = res1.to_s

    # remove field_2 to pretend we never knew about it
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_3, 3
      end
    end

    res2 = nil
    expect do
      res2 = TehUnknown2::MyResult.parse(serialized)
    end.not_to raise_error()

    expect(res2.field_1).to eq(0xffff)
    expect(res2.field_3).to eq(0xfffd)

    expect do
      expect(res2.field_2).to eq(0xfffe)
    end.to raise_error(NoMethodError)

    serialized2 = res2.to_s

    # now we know about field_2 again
    module TehUnknown3
      class MyResult < ProtocolBuffers::Message
        optional :int32, :field_1, 1
        optional :int32, :field_2, 2
        optional :int32, :field_4, 4
      end
    end

    res3 = TehUnknown3::MyResult.parse(serialized2)
    expect(res3.field_1).to eq(0xffff)

    expect(res3.field_2).to eq(0xfffe)
    expect(res3.field_4).to eq(0xfffc)
  end

  it "ignores and passes on unknown enum values" do
    module TehUnknown
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
          V2 = 2
        end
        optional E, :field_1, 1
      end
    end

    res1 = TehUnknown::MyResult.new(:field_1 => TehUnknown::MyResult::E::V2)
    serialized = res1.to_s

    # remove field_2 to pretend we never knew about it
    module TehUnknown2
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
        end
        optional E, :field_1, 1
      end
    end

    res2 = nil
    expect do
      res2 = TehUnknown2::MyResult.parse(serialized)
    end.not_to raise_error()

    expect(res2.value_for_tag?(1)).to be_falsey
    expect(res2.unknown_field_count).to eq(1)

    serialized2 = res2.to_s

    # now we know about field_2 again
    module TehUnknown3
      class MyResult < ProtocolBuffers::Message
        module E
          include ProtocolBuffers::Enum
          V1 = 1
          V2 = 2
        end
        optional E, :field_1, 1
      end
    end

    res3 = TehUnknown3::MyResult.parse(serialized2)
    expect(res3.field_1).to eq(2)
  end

  describe "Message#valid?" do
    it "should validate sub-messages" do
      f = Featureful::A.new
      f.i3 = 1
      f.sub3 = Featureful::A::Sub.new
      expect(f.valid?).to eq(false)
      expect(f.sub3.valid?).to eq(false)
      f.sub3.payload_type = Featureful::A::Sub::Payloads::P1
      expect(f.valid?).to eq(false)
      expect(f.group3.valid?).to eq(false)
      f.group3.i1 = 1
      expect(f.valid?).to eq(true)
      expect(f.sub3.valid?).to eq(true)
    end
  end

  it "should work with IO streams not set to binary" do
    pending("requires encoding support") unless "".respond_to?(:encoding)
    class IntMsg < ProtocolBuffers::Message
      required :int32, :i, 1
    end
    sio = StringIO.new("\b\xc3\x911")
    sio.set_encoding('utf-8')
    msg = IntMsg.parse(sio)
    expect(msg.i).to eq(805059)
  end

  it "handles if you set a repeated field to itself" do
    f = Featureful::A.new
    f.i1 = [1, 2, 3]
    f.i1 = f.i1
    expect(f.i1).to match_array([1, 2, 3])
  end

  it "correctly converts to a hash" do
    f = Featureful::A.new
    f.i1 = [1, 2, 3]
    f.i3 = 4
    sub11 = Featureful::A::Sub.new
    sub11.payload = "sub11payload"
    sub11.payload_type = Featureful::A::Sub::Payloads::P1
    sub11.subsub1.subsub_payload = "sub11subsubpayload"
    sub12 = Featureful::A::Sub.new
    sub12.payload = "sub12payload"
    sub12.payload_type = Featureful::A::Sub::Payloads::P2
    sub12.subsub1.subsub_payload = "sub12subsubpayload"
    f.sub1 = [sub11, sub12]
    f.sub3.payload = "sub3payload"
    f.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    f.sub3.subsub1.subsub_payload = "sub3subsubpayload"
    f.group3.i1 = 1

    expect(f.valid?).to eq(true)
    expect(f.to_hash).to eq({
      :i1 => [1, 2, 3],
      :i3 => 4,
      :sub1 => [
        {
          :payload => "sub11payload",
          :payload_type => 0,
          :subsub1 => {
            :subsub_payload => "sub11subsubpayload"
          }
        },
        {
          :payload => "sub12payload",
          :payload_type => 1,
          :subsub1 => {
            :subsub_payload => "sub12subsubpayload"
          }
        }
      ],
      :sub3 => {
        :payload => "sub3payload",
        :payload_type => 0,
        :subsub1 => {
          :subsub_payload => "sub3subsubpayload"
        }
      },
      :group1 => [],
      :group3 => {
        :i1 => 1,
        :subgroup => []
      }
    })

  end

  it "includes default values set in the .proto files in the hash" do
    bit = Featureful::ABitOfEverything.new.to_hash
    expect(bit).to eq({int64_field: 15, bool_field: false, string_field: 'zomgkittenz'})
  end

  it "correctly handles ==, eql? and hash" do
    f1 = Featureful::A.new
    f1.i1 = [1, 2, 3]
    f1.i3 = 4
    sub111 = Featureful::A::Sub.new
    sub111.payload = "sub11payload"
    sub111.payload_type = Featureful::A::Sub::Payloads::P1
    sub111.subsub1.subsub_payload = "sub11subsubpayload"
    sub112 = Featureful::A::Sub.new
    sub112.payload = "sub12payload"
    sub112.payload_type = Featureful::A::Sub::Payloads::P2
    sub112.subsub1.subsub_payload = "sub12subsubpayload"
    f1.sub1 = [sub111, sub112]
    f1.sub3.payload = ""
    f1.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    f1.sub3.subsub1.subsub_payload = "sub3subsubpayload"
    f1.group3.i1 = 1

    f2 = Featureful::A.new
    f2.i1 = [1, 2, 3]
    f2.i3 = 4
    sub211 = Featureful::A::Sub.new
    sub211.payload = "sub11payload"
    sub211.payload_type = Featureful::A::Sub::Payloads::P1
    sub211.subsub1.subsub_payload = "sub11subsubpayload"
    sub212 = Featureful::A::Sub.new
    sub212.payload = "sub12payload"
    sub212.payload_type = Featureful::A::Sub::Payloads::P2
    sub212.subsub1.subsub_payload = "sub12subsubpayload"
    f2.sub1 = [sub211, sub212]
    f2.sub3.payload = ""
    f2.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    f2.sub3.subsub1.subsub_payload = "sub3subsubpayload"
    f2.group3.i1 = 1

    # different because subsub1.sub_payload different
    f3 = Featureful::A.new
    f3.i1 = [1, 2, 3]
    f3.i3 = 4
    sub311 = Featureful::A::Sub.new
    sub311.payload = "sub11payload"
    sub311.payload_type = Featureful::A::Sub::Payloads::P1
    sub311.subsub1.subsub_payload = "sub11subsubpayload"
    sub312 = Featureful::A::Sub.new
    sub312.payload = "sub12payload"
    sub312.payload_type = Featureful::A::Sub::Payloads::P2
    sub312.subsub1.subsub_payload = "sub12subsubpayload_DIFFERENT"
    f3.sub1 = [sub311, sub312]
    f3.sub3.payload = ""
    f3.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    f3.sub3.subsub1.subsub_payload = "sub3subsubpayload"
    f3.group3.i1 = 1

    # different because sub3.payload not set
    f4 = Featureful::A.new
    f4.i1 = [1, 2, 3]
    f4.i3 = 4
    sub411 = Featureful::A::Sub.new
    sub411.payload = "sub11payload"
    sub411.payload_type = Featureful::A::Sub::Payloads::P1
    sub411.subsub1.subsub_payload = "sub11subsubpayload"
    sub412 = Featureful::A::Sub.new
    sub412.payload = "sub12payload"
    sub412.payload_type = Featureful::A::Sub::Payloads::P2
    sub412.subsub1.subsub_payload = "sub12subsubpayload"
    f4.sub1 = [sub411, sub412]
    f4.sub3.payload_type = Featureful::A::Sub::Payloads::P1
    f4.sub3.subsub1.subsub_payload = "sub3subsubpayload"
    f4.group3.i1 = 1

    expect(f1).to eq(f2)
    expect(f1).not_to eq(f3)
    expect(f1).not_to eq(f4)
    expect(f2).to eq(f1)
    expect(f2).not_to eq(f3)
    expect(f2).not_to eq(f4)
    expect(f3).not_to eq(f1)
    expect(f3).not_to eq(f2)
    expect(f3).not_to eq(f4)

    expect(f1.eql?(f2)).to eq(true)
    expect(f1.eql?(f3)).not_to eq(true)
    expect(f1.eql?(f4)).not_to eq(true)
    expect(f2.eql?(f1)).to eq(true)
    expect(f2.eql?(f3)).not_to eq(true)
    expect(f2.eql?(f4)).not_to eq(true)
    expect(f3.eql?(f1)).not_to eq(true)
    expect(f3.eql?(f2)).not_to eq(true)
    expect(f3.eql?(f4)).not_to eq(true)

    expect(f1.hash).to eq(f2.hash)
    expect(f1.hash).not_to eq(f3.hash)
    expect(f1.hash).not_to eq(f4.hash)
    expect(f2.hash).to eq(f1.hash)
    expect(f2.hash).not_to eq(f3.hash)
    expect(f2.hash).not_to eq(f4.hash)
    expect(f3.hash).not_to eq(f1.hash)
    expect(f3.hash).not_to eq(f2.hash)
    expect(f3.hash).not_to eq(f4.hash)
  end

  it "correctly handles fully qualified names on Messages" do
    expect(Simple::Test1.fully_qualified_name).to eq("simple.Test1")
    expect(Simple::Foo.fully_qualified_name).to eq("simple.Foo")
    expect(Simple::Bar.fully_qualified_name).to eq(nil)
  end

  it "correctly handles fully qualified names on Messages with no package" do
    expect(A.fully_qualified_name).to eq("A")
    expect(A::B.fully_qualified_name).to eq("A.B")
    expect(C.fully_qualified_name).to eq(nil)
  end

  it "has only Enum values as constants" do
    expect(Enums::FooEnum.constants.map(&:to_sym)).to match_array([:ONE, :TWO, :THREE])
    expect(Enums::BarEnum.constants.map(&:to_sym)).to match_array([:FOUR, :FIVE, :SIX])
    expect(Enums::FooMessage::NestedFooEnum.constants.map(&:to_sym)).to match_array([:SEVEN, :EIGHT])
    expect(Enums::FooMessage::NestedBarEnum.constants.map(&:to_sym)).to match_array([:NINE, :TEN])
  end

  it "correctly populates the maps between name and values for Enums" do
    expect(Enums::FooEnum.value_to_names_map).to eq({
      1 => [:ONE],
      2 => [:TWO],
      3 => [:THREE]
    })
    expect(Enums::BarEnum.value_to_names_map).to eq({
      4 => [:FOUR],
      5 => [:FIVE],
      6 => [:SIX]
    })
    expect(Enums::FooEnum.name_to_value_map).to eq({
      :ONE => 1,
      :TWO => 2,
      :THREE => 3
    })
    expect(Enums::BarEnum.name_to_value_map).to eq({
      :FOUR => 4,
      :FIVE => 5,
      :SIX => 6
    })
    expect(Enums::FooMessage::NestedFooEnum.value_to_names_map).to eq({
      7 => [:SEVEN],
      8 => [:EIGHT],
    })
    expect(Enums::FooMessage::NestedBarEnum.value_to_names_map).to eq({
      9 => [:NINE],
      10 => [:TEN],
    })
    expect(Enums::FooMessage::NestedFooEnum.name_to_value_map).to eq({
      :SEVEN => 7,
      :EIGHT => 8,
    })
    expect(Enums::FooMessage::NestedBarEnum.name_to_value_map).to eq({
      :NINE => 9,
      :TEN => 10,
    })
  end

  it "correctly handles fully qualified names on Enums" do
    expect(Enums::FooEnum.fully_qualified_name).to eq("enums.FooEnum")
    expect(Enums::BarEnum.fully_qualified_name).to eq(nil)
    expect(Enums::FooMessage::NestedFooEnum.fully_qualified_name).to eq("enums.FooMessage.NestedFooEnum")
    expect(Enums::FooMessage::NestedBarEnum.fully_qualified_name).to eq(nil)
  end

  it "correctly handles service definitions" do
    get_foo_rpc, get_bar_rpc = get_rpcs

    expect(get_foo_rpc.name).to eq(:get_foo)
    expect(get_foo_rpc.proto_name).to eq("GetFoo")
    expect(get_foo_rpc.request_class).to eq(Services::FooRequest)
    expect(get_foo_rpc.response_class).to eq(Services::FooResponse)
    expect(get_foo_rpc.service_class).to eq(Services::FooBarService)

    expect(get_bar_rpc.name).to eq(:get_bar)
    expect(get_bar_rpc.proto_name).to eq("GetBar")
    expect(get_bar_rpc.request_class).to eq(Services::BarRequest)
    expect(get_bar_rpc.response_class).to eq(Services::BarResponse)
    expect(get_bar_rpc.service_class).to eq(Services::FooBarService)
  end

  it "correctly handles == for Rpcs" do
    get_foo_rpc, get_bar_rpc = get_rpcs

    expect(get_foo_rpc).to eq(get_foo_rpc)
    expect(get_bar_rpc).to eq(get_bar_rpc)
    expect(get_foo_rpc).not_to eq(get_bar_rpc)
  end

  it "correctly freezes rpcs" do
    get_foo_rpc, get_bar_rpc = get_rpcs

    expect(get_foo_rpc.frozen?).to eq(true)
    expect(get_bar_rpc.frozen?).to eq(true)
    expect(get_foo_rpc.proto_name.frozen?).to eq(true)
    expect(get_bar_rpc.proto_name.frozen?).to eq(true)

    # make sure to_s is still possible when frozen
    get_foo_rpc.to_s
    get_bar_rpc.to_s

    expect(Services::FooBarService.rpcs.frozen?).to eq(true)
  end

  it "correctly handles fully qualified names on Services" do
    expect(Services::FooBarService.fully_qualified_name).to eq("services.FooBarService")
    expect(Services::NoNameFooBarService.fully_qualified_name).to eq(nil)
  end

  def get_rpcs
    expect(Services::FooBarService.rpcs.size).to eq(2)
    first_rpc = Services::FooBarService.rpcs[0]
    second_rpc = Services::FooBarService.rpcs[1]
    case first_rpc.name
    when :get_foo
      expect(second_rpc.name).to eq(:get_bar)
      return first_rpc, second_rpc
    when :get_bar
      expect(first_rpc.name).to eq(:get_bar)
      return second_rpc, first_rpc
    else raise ArgumentError.new(first_rpc.name)
    end
  end
end
