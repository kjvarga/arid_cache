require 'spec_helper'

describe AridCache::CacheProxy do
  describe 'preserve_order' do
    before :each do
      @proxy = AridCache::CacheProxy.new(Company, 'dummy-key', {})
    end

    it "id column should be prefixed by the table name" do
      ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(true)
      @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
    end

    it "id column should be prefixed by the table name" do
      ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(false)
      @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
    end
  end

  describe "with raw => true" do
    before :each do
      @user = User.make
      @user.companies << Company.make
      @user.companies << Company.make
      @user.clear_instance_caches
    end

    it "should return a CacheProxy::Result" do
      @user.cached_companies(:raw => true).should be_a(AridCache::CacheProxy::Result)
    end

    it "result should have the same ids as the normal result" do
      @user.cached_companies(:raw => true).ids.should == @user.cached_companies.collect(&:id)
    end

    it "should ignore :raw => false" do
      @user.cached_companies(:raw => false).should == @user.cached_companies
    end

    it "should only query once to seed the cache, ignoring all other options" do
      lambda { @user.cached_companies(:raw => true, :limit => 0, :order => 'nonexistent_column desc') }.should query(1)
    end

    it "should ignore all other options if the cache has already been seeded" do
      lambda {
        companies = @user.cached_companies
        @user.cached_companies(:raw => true, :limit => 0, :order => 'nonexistent_column').ids.should == companies.collect(&:id)
      }.should query(1)
    end

    it "should not use the raw option when reading from the cache" do
      Rails.cache.expects(:read).with(@user.arid_cache_key(:companies), {})
      @user.cached_companies(:raw => true)
    end
  end
end