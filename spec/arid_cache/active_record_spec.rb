require 'spec_helper'

describe AridCache::ActiveRecord do
  describe 'respond_to?' do
    before :each do
      @class = Class.new { include AridCache }.new
    end

    it "should not fail if a superclass doesn't include AridCache" do
      lambda {
        @class.respond_to?(:cached_xxx).should be_false
      }.should_not raise_error(NoMethodError)
    end
  end

  describe "arid_cache_key" do
    before :each do
      @user = User.make
    end

    it "should generate cache key for a class" do
      User.arid_cache_key('companies').should == 'arid-cache-user-companies'
    end

    it "should generate cache key for an instance" do
      @user.arid_cache_key('companies').should == "arid-cache-users/#{@user.id}-companies"
    end

    it "should generate auto-expiring cache key" do
      updated_at = @user.updated_at.utc.to_s(:number)
      @user.arid_cache_key('companies', :auto_expire => true).should == "arid-cache-users/#{@user.id}-#{updated_at}-companies"
    end

    it "should generate cache key given an id" do
      @user.arid_cache_key('companies').should == User.arid_cache_key(@user.id, 'companies')
    end

    it "should support a symbol for the key" do
      @user.arid_cache_key(:companies).should == @user.arid_cache_key('companies')
    end
  end
end
