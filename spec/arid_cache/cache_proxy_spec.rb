require 'spec_helper'

describe AridCache::CacheProxy do
  before :all do
    AridCache.store.delete! # so no options get stored
  end

  describe "with raw => true" do
    before :each do
      @user = User.make
      @user.companies << Company.make
      @user.companies << Company.make
      @user.clear_instance_caches
    end

    describe "with options" do
      before :all do
        AridCache.raw_with_options = true
      end

      after :all do
        AridCache.raw_with_options = false
      end

      it "should use the new raw handling" do
        AridCache.raw_with_options.should be_true
      end

      it "should return raw results" do
        @user.cached_companies(:raw => true).should == @user.companies.collect(&:id)
      end

      it "result should have the same ids as the normal result" do
        @user.cached_companies(:raw => true).should == @user.cached_companies.collect(&:id)
      end

      it "should ignore :raw => false" do
        @user.cached_companies(:raw => false).should == @user.cached_companies
      end

      it "should only query once to seed the cache, ignoring all other options" do
        lambda { @user.cached_companies(:raw => true, :limit => 0, :order => 'nonexistent_column desc') }.should query(1)
      end

      it "should apply options even if the cache has already been seeded" do
        lambda {
          companies = @user.cached_companies
          @user.cached_companies(:raw => true, :limit => 1).should == companies.collect(&:id)[0,1]
        }.should query(1)
      end

      it "should not use the raw option when reading from the cache" do
        mock.proxy(Rails.cache).read(@user.arid_cache_key(:companies), {})
        @user.cached_companies(:raw => true)
      end

      it "should work for calls to a method that ends with _count" do
        @user.cached_bogus_count do
          10
        end
        @user.cached_bogus_count(:raw => true).should == 10
      end

      it "should work for calls to a method that ends with _count" do
        @user.cached_companies_count(:raw => true).should == @user.cached_companies_count
      end
    end

    describe "deprecated" do
      it "should use the deprecated handling" do
        AridCache.raw_with_options.should be_false
      end

      it "should return a CacheProxy::CachedResult" do
        @user.cached_companies(:raw => true).should be_a(AridCache::CacheProxy::CachedResult)
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
        mock.proxy(Rails.cache).read(@user.arid_cache_key(:companies), {})
        @user.cached_companies(:raw => true)
      end

      it "should work for calls to a method that ends with _count" do
        @user.cached_bogus_count do
          10
        end
        @user.cached_bogus_count(:raw => true).should == 10
      end

      it "should work for calls to a method that ends with _count" do
        @user.cached_companies_count(:raw => true).should == @user.cached_companies_count
      end
    end
  end

  describe "with clear => true" do
    before :each do
      @user = User.make
      @user.companies << Company.make
      @user.companies << Company.make
      @user.clear_instance_caches rescue Rails.cache.clear
    end

    it "should not fail if there is no cached value" do
      lambda { @user.cached_companies(:clear => true) }.should_not raise_exception
    end

    it "should clear the cached entry" do
      key = @user.arid_cache_key(:companies)
      @user.cached_companies
      Rails.cache.read(key).should_not be_nil
      @user.cached_companies(:clear => true)
      Rails.cache.read(key).should be_nil
    end

    it "should not read from the cache or database" do
      dont_allow(Rails.cache).read
      lambda {
        @user.cached_companies(:clear => true)
      }.should query(0)
    end
  end

  describe "nils" do
    before :each do
      @obj = Class.new do
        include AridCache

        instance_caches do
          empty { nil }
        end
      end.new
      @obj.cached_empty(:clear => true)
    end

    it "should cache nils" do
      @obj.cached_empty.should be_nil
    end

    it "should only write to the cache once" do
      mock.proxy(Rails.cache).read.with_any_args.twice
      mock.proxy(Rails.cache).write.with_any_args.once
      @obj.cached_empty
      @obj.cached_empty
    end

    it "should return nil for the count" do
      @obj.cached_empty_count.should be_nil
    end

    it "should return nil for :raw => true" do
      @obj.cached_empty(:raw => true).should be_nil
    end

    it "should be cached as a CachedResult" do
      @obj.cached_empty
      cached = Rails.cache.read(@obj.arid_cache_key(:empty))
      cached.should be_a(AridCache::CacheProxy::CachedResult)
      cached.klass.should == NilClass
    end
  end

  describe "arrays" do
    before :each do
      @o = Class.new do
        include AridCache
        def result
          @result ||= (1..5).to_a
        end
      end.new
    end

    it "should cache the result" do
      @o.cached_result.should == @o.result
    end

    it "should respect the :limit option" do
      @o.cached_result(:limit => 4).should == [1,2,3,4]
    end

    it "should respect the :offset option" do
      @o.cached_result(:offset => 2).should == [3,4,5]
    end

    it "should apply pagination" do
      result = @o.cached_result(:page => 2, :per_page => 2)
      result.should == @o.result.paginate(:page => 2, :per_page => 2)
      result.total_entries.should == @o.result.size
    end
  end

  describe "CachedResult" do
    before :each do
      class User
        instance_caches do
          get_result
        end

        def get_result
          AridCache::CacheProxy::CachedResult.new(companies.collect(&:id), Company, companies.count)
        end
      end
      @user = User.make
      @user.companies << Company.make
      @user.companies << Company.make
    end

    it "should store a CachedResult" do
      @user.cached_get_result
      Rails.cache.read(@user.arid_cache_key(:get_result)).should == @user.get_result
    end

    it "should return records" do
      @user.cached_get_result.should == @user.companies
    end

    it "should return a count" do
      @user.cached_get_result_count.should == @user.companies.count
    end

    it "should return the CachedResult with :raw => true" do
      @user.cached_get_result(:raw => true).should == @user.get_result
    end
  end
end
