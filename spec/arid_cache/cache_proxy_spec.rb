require 'spec_helper'

describe AridCache::CacheProxy do
  # describe 'preserve_order' do
  #   before :each do
  #     @proxy = AridCache::CacheProxy.new(Company, 'dummy-key', {})
  #   end
  # 
  #   it "id column should be prefixed by the table name" do
  #     ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(true)
  #     @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
  #   end
  # 
  #   it "id column should be prefixed by the table name" do
  #     ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(false)
  #     @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
  #   end
  # end
  # 
  # describe "with raw => true" do
  #   before :each do
  #     @user = User.make
  #     @user.companies << Company.make
  #     @user.companies << Company.make
  #     @user.clear_instance_caches
  #   end
  # 
  #   it "should return a CacheProxy::CachedActiveRecordResult" do
  #     @user.cached_companies(:raw => true).should be_a(AridCache::CacheProxy::CachedActiveRecordResult)
  #   end
  # 
  #   it "result should have the same ids as the normal result" do
  #     @user.cached_companies(:raw => true).ids.should == @user.cached_companies.collect(&:id)
  #   end
  # 
  #   it "should ignore :raw => false" do
  #     @user.cached_companies(:raw => false).should == @user.cached_companies
  #   end
  # 
  #   it "should only query once to seed the cache, ignoring all other options" do
  #     lambda { @user.cached_companies(:raw => true, :limit => 0, :order => 'nonexistent_column desc') }.should query(1)
  #   end
  # 
  #   it "should ignore all other options if the cache has already been seeded" do
  #     lambda {
  #       companies = @user.cached_companies
  #       @user.cached_companies(:raw => true, :limit => 0, :order => 'nonexistent_column').ids.should == companies.collect(&:id)
  #     }.should query(1)
  #   end
  # 
  #   it "should not use the raw option when reading from the cache" do
  #     Rails.cache.expects(:read).with(@user.arid_cache_key(:companies), {})
  #     @user.cached_companies(:raw => true)
  #   end
  # 
  #   it "should work for calls to a method that ends with _count" do
  #     @user.cached_bogus_count do
  #       10
  #     end
  #     @user.cached_bogus_count(:raw => true).should == 10
  #   end
  # 
  #   it "should work for calls to a method that ends with _count" do
  #     @user.cached_companies_count(:raw => true).should == @user.cached_companies_count
  #   end
  # end
  # 
  # describe "with clear => true" do
  #   before :each do
  #     @user = User.make
  #     @user.companies << Company.make
  #     @user.companies << Company.make
  #     @user.clear_instance_caches rescue Rails.cache.clear
  #   end
  # 
  #   it "should not fail if there is no cached value" do
  #     lambda { @user.cached_companies(:clear => true) }.should_not raise_exception
  #   end
  # 
  #   it "should clear the cached entry" do
  #     key = @user.arid_cache_key(:companies)
  #     @user.cached_companies
  #     Rails.cache.read(key).should_not be_nil
  #     @user.cached_companies(:clear => true)
  #     Rails.cache.read(key).should be_nil
  #   end
  # 
  #   it "should not read from the cache or database" do
  #     Rails.cache.expects(:read).never
  #     lambda {
  #       @user.cached_companies(:clear => true)
  #     }.should query(0)
  #   end
  # end
  
  describe "arrays" do
    before :each do
      @o = Class.new do
        include AridCache
        def result
          @result ||= (1..5).to_a
        end
      end.new
    end

    # it "should cache the result" do
    #   @o.cached_result { result }.should == @o.result 
    # end
    # 
    # it "should respect the :limit option" do
    #   @o.cached_result(:limit => 4) { result }.should == [1,2,3,4]
    # end

    it "should respect the :offset option" do
      @o.cached_result(:offset => 2) { result }.should == [3,4,5]
    end
  
    # it "should apply pagination" do
    #   result = @o.cached_result(:page => 2, :per_page => 2) { result }
    #   result.should == @o.paginate(:page => 2, :per_page => 2)
    #   result.total_entries.should == @o.result.size
    # end
  end
end