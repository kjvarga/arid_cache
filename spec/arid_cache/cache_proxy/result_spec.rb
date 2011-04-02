require 'spec_helper'

describe AridCache::CacheProxy::Result do
  before :each do
    @result = AridCache::CacheProxy::Result.new([])
  end
  it "should yield the block to the instance" do
    @result.is_enumerable?.should be_true
    @result.is_empty?.should be_false
    @result.is_activerecord?.should be_false
  end
end