# Tests for issues with decoding negative int32 fields

# By Mark Herman <mherman@iseatz.com> based on code from
# Tom Zetty <tzetty@iseatz.com>

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'

describe "Testing for decode errors for negative int32 fields" do
  # These should fail without the int32 negative handling fix
  it "should return -1 given -1" do
    expect(validate_pbr(SignedIntTest, -1, true)).to be_truthy
  end

  it "should return -1111 given -1111" do
    expect(validate_pbr(SignedIntTest, -1111, true)).to be_truthy
  end

  # These should pass with or without the negative handling fix
  it "should return 1 given 1" do
    expect(validate_pbr(SignedIntTest, 1, true)).to be_truthy
  end

  it "should return 0 given 0" do
    expect(validate_pbr(SignedIntTest, 0, true)).to be_truthy
  end

  it "should return 100000 given 100000" do
    expect(validate_pbr(SignedIntTest, 100000, true)).to be_truthy    
  end
end
