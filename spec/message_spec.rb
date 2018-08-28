# encoding: binary

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'

describe ProtocolBuffers, "message" do
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

  module TestMessages
    class Name < ::ProtocolBuffers::Message
      set_fully_qualified_name "test_messages.Name"
      required :string, :value, 1
      required :string, :other_value, 2
    end

    class FullName < ::ProtocolBuffers::Message
      class List < ::ProtocolBuffers::Message
        set_fully_qualified_name "test_messages.List"
        required Name, :thing_one, 1
        required Name, :thing_two, 2
      end

      set_fully_qualified_name "test_messages.FullName"
      required Name, :first_name, 1
      required Name, :last_name, 2
      repeated List, :list_o_stuff, 3
    end

    class SystemInfo < ::ProtocolBuffers::Message
      set_fully_qualified_name "test_messages.SystemInfo"
      required :string, :name, 1
      required FullName, :full_name, 2
    end

    class Header < ::ProtocolBuffers::Message
      set_fully_qualified_name "test_messages.Header"
      required :string, :id, 1
      required :string, :occurred_at, 2
    end

    class Flatty < ::ProtocolBuffers::Message
      set_fully_qualified_name "test_messages.Flatty"
      required :string, :stuff, 1
      required :string, :happened, 2
      required :bool, :flat, 3
    end

    class Command < ::ProtocolBuffers::Message
      set_fully_qualified_name "test_messages.Command"
      required Header, :header, 1
      required SystemInfo, :value, 2
      required Flatty, :flatty, 3
      required :bool, :on, 4
    end
  end

  it "should build a message with nested types from a hash with a matching schema" do
    id = "one"
    system_name = "The System Name"
    occurred_at = Time.now.utc.to_s
    header = Hash[ id: id, occurred_at: occurred_at ]
    flatty = Hash[ stuff: "Stuff", happened: "Happened", flat: true]
    first_name = Hash[value: "First Name", other_value: "Secret First Name"]
    last_name = Hash[value: "Last Name", other_value: "Secret First Name"]
    full_name = Hash[first_name: first_name, last_name: last_name, list_o_stuff: [{thing_one: first_name, thing_two: last_name}, {thing_one: first_name, thing_two: last_name}]] #
    name = Hash[ name: system_name, full_name: full_name]
    hash = Hash[header: header, value: name, flatty: flatty, on: true]

    message = TestMessages::Command.from_hash(hash)

    expect(message).to be_instance_of(TestMessages::Command)
    expect(message.header).to be_instance_of(TestMessages::Header)
    expect(message.header.id).to eq(id)
    expect(message.header.occurred_at).to eq(occurred_at)

    expect(message.value).to be_instance_of(TestMessages::SystemInfo)
    expect(message.value.name).to eq(system_name)

    expect(message.value.full_name).to be_instance_of(TestMessages::FullName)

    expect(message.value.full_name.first_name).to be_instance_of(TestMessages::Name)
    expect(message.value.full_name.first_name.value).to eq(first_name[:value])

    expect(message.value.full_name.last_name).to be_instance_of(TestMessages::Name)
    expect(message.value.full_name.last_name.value).to eq(last_name[:value])

    expect(message.value.full_name.list_o_stuff).to be_instance_of(ProtocolBuffers::RepeatedField)
    message.value.full_name.list_o_stuff.each do |f|
      expect(f).to be_instance_of(TestMessages::FullName::List)
    end
  end

  it "defaults to an empty hash if nil is passed to the constructor" do
    expect(Featureful::A.new()).to eq(Featureful::A.new({}))
    expect(Featureful::A.new(nil)).to eq(Featureful::A.new({}))
  end

  it "correctly handles value_for_tag? when fields are set in the constructor" do
    a = Featureful::A.new(
      :i2 => 1,
      :sub2 => Featureful::A::Sub.new(
        :payload => "test_payload"
      )
    )

    expect(a.value_for_tag?(1)).to eq(true)
    expect(a.value_for_tag?(5)).to eq(true)
  end

  it "correctly handles value_for_tag? when a MessageField is set to the same object in two locations within the same proto and set in the constructor" do
    d = Featureful::D.new(
      :f => [1, 2, 3].map do |num|
        Featureful::F.new(
          :s => "#{num}"
        )
      end
    )
    c = Featureful::C.new(
      :d => d,
      :e => [1].map do |num|
        Featureful::E.new(
          :d => d
        )
      end
    )

    expect(c.value_for_tag?(1)).to eq(true)
  end

  it "correctly handles value_for_tag? when a Messagefield is set to the same object in two locations within the same proto and set outside of the constructor" do
    d = Featureful::D.new
    d.f = [1, 2, 3].map do |num|
      Featureful::F.new(
        :s => "#{num}"
      )
    end
    c = Featureful::C.new
    c.d = d
    c.e = [1].map do |num|
      Featureful::E.new(
        :d => d
      )
    end

    expect(c.value_for_tag?(1)).to eq(true)
  end

  it "correctly handles value_for_tag? when a field is accessed and then modified and this field is a MessageField with only a repeated field accessed" do
    c = Featureful::C.new
    c_d = c.d
    c_d.f = [1, 2, 3].map do |num|
      Featureful::F.new(
        :s => "#{num}"
      )
    end
    d = Featureful::D.new
    d.f = [1, 2, 3].map do |num|
      Featureful::F.new(
        :s => "#{num}"
      )
    end
    c.e = [1].map do |num|
      Featureful::E.new(
        :d => d
      )
    end

    expect(c.value_for_tag?(1)).to eq(true)
  end

  it "correctly handles value_for_tag? when a field is accessed and then modified and this field is a MessageField with a repeated and required field accessed" do
    c = Featureful::C.new
    c_d = c.d
    c_d.f = [1, 2, 3].map do |num|
      Featureful::F.new(
        :s => "#{num}"
      )
    end
    d = Featureful::D.new
    d.f = [1, 2, 3].map do |num|
      Featureful::F.new(
        :s => "#{num}"
      )
    end
    d.f2 = Featureful::F.new(
      :s => "4"
    )
    c.e = [1].map do |num|
      Featureful::E.new(
        :d => d
      )
    end

    expect(c.value_for_tag?(1)).to eq(true)
  end

  it "correctly handles get" do
    f = Featureful::A.new
    f.i3 = 4
    f.sub3.subsub1.subsub_payload = "sub3subsubpayload"

    expect(f.get(:sub3, :subsub1, :subsub_payload)).to eq("sub3subsubpayload")
    expect(f.get(:i3)).to eq(4)
    expect(f.get(:i2)).to eq(nil)
    expect(f.get(:sub2)).to eq(nil)
  end

  it "correctly handles get!" do
    f = Featureful::A.new
    f.i3 = 4
    f.sub3.subsub1.subsub_payload = "sub3subsubpayload"

    expect(f.get!(:sub3, :subsub1, :subsub_payload)).to eq("sub3subsubpayload")
    expect(f.get!(:i3)).to eq(4)
    expect { f.get!(:i2) }.to raise_error(ArgumentError)
    expect { f.get!(:sub2) }.to raise_error(ArgumentError)
  end
end
