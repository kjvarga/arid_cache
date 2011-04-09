require 'spec_helper'

describe AridCache::CacheProxy::CachedResult do
  before :each do
    class X; end
    @result = AridCache::CacheProxy::CachedResult.new
  end

  it "should set the klass from a class" do
    @result.klass = X
    @result.klass.should be(X)
  end

  it "should set the klass from an object" do
    @result.klass = X.new
    @result.klass.should be(X)
  end

  it "should store the klass as a string" do
    @result.klass = X
    @result[:klass].should == X.name
  end

  it "should not have ids if it's nil" do
    @result.ids = nil
    @result.has_ids?.should be_false
  end

  it "should have ids" do
    @result.ids = [1,2,3]
    @result.has_ids?.should be_true
  end

  it "should have ids even if the array is empty" do
    @result.ids = []
    @result.has_ids?.should be_true
  end

  it "should not have a count if it's nil" do
    @result.count = nil
    @result.has_count?.should be_false
  end

  it "should have a count" do
    @result.count = 3
    @result.has_count?.should be_true
  end

  it "should have a count even if it is zero" do
    @result.count = 0
    @result.has_count?.should be_true
  end

  it "should handle initializing with a klass" do
    @result = AridCache::CacheProxy::CachedResult.new([], X, 0)
    @result.klass.should == X
  end
end
