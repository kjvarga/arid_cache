require 'spec_helper'

describe AridCache::ActiveRecord do
  context 'respond_to?' do
    before :each do
      @class = Class.new(Class.new)
      @class.send(:include, AridCache)
    end

    it "should not fail if a superclass doesn't include AridCache" do
      lambda {
        @class.respond_to?(:cached_xxx).should be_false
      }.should_not raise_error(NoMethodError)
    end
  end
end