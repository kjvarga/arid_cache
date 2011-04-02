require 'spec_helper'

describe AridCache::CacheProxy::ResultProcessor do
  describe "empty array" do
    before :each do
      @result = AridCache::CacheProxy::ResultProcessor.new([])
    end

    it "should recognize an empty array" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_true
      @result.is_activerecord?.should be_false
      @result.to_cache.should be_a(AridCache::CacheProxy::CachedResult)
    end
  end

  describe "empty array" do
    before :each do
      @result = AridCache::CacheProxy::ResultProcessor.new([1,2,3])
    end

    it "should recognize an empty array" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_false
      @result.is_activerecord?.should be_false
      @result.to_cache.should == [1,2,3]
    end
  end
end