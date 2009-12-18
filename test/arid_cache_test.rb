require 'test_helper'

class AridCacheTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
    get_user
  end
  
  test "should respond to methods" do
    assert_respond_to(User, :cache_store)
    assert_respond_to(User.first, :cache_store)
    assert_instance_of AridCache::Store, User.cache_store
  end
  
  test "should define methods on the instance" do
    
  end  
    
  test "should not clobber method_missing" do
    assert_respond_to User.first, :name                                                                  
  end 

  test "should allow access to valid methods" do
    assert_nothing_raised { User.first.is_high? }
    assert User.first.is_high?
  end 
    
  test "should allow me to cache on the model" do
    assert_nothing_raised do
      define_model_cache(User)
    end
    assert_instance_of(Proc, User.cache_store[:'user-companies'])
  end

  test "should allow me to cache on the instance" do
    assert_nothing_raised do
      define_instance_cache(@user)
    end
    assert_instance_of(Proc, @user.cache_store[:"#{@user.cache_key}-companies"])
  end
    
  test "should raise an error on invalid dynamic caches" do
    assert_raises ArgumentError do
      @user.cached_invalid_companies
    end
  end

  test "should create dynamic caches given valid arguments" do
    assert_nothing_raised { @user.cached_companies }
    assert_instance_of(Proc, @user.cache_store[:"#{@user.cache_key}-companies"])
  end

  test "counts queries correctly" do
    assert_queries(1) { User.all }
  end
  
  test "sets count for free" do
    assert_queries(1) do
      @user.cached_companies
      @user.cached_companies_count
    end
  end

  test "returns valid results" do
    @one = @user.cached_companies
    assert_equal @one, @user.companies
    assert @one.size, @user.companies.count
  end
  
  test "paginates results" do
    results = @user.cached_companies(:page => 1, :per_page => 2)
    assert_kind_of WillPaginate::Collection, results
    assert_equal 2, results.size
    assert_equal 5, results.total_entries    
  end
  
  test "returns_dynamic_count" do
    assert_queries(1) do
      assert_equal 5, @user.cached_companies_count
      assert_equal 5, @user.cached_companies_count
    end
  end
    
  protected

    def get_user
      @user = User.first
      @user.cache_store.delete!
      @user
    end
    
    def assert_queries(num = 1)
      $query_count = 0
      yield
    ensure
      assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
    end

    def assert_no_queries(&block)
      assert_queries(0, &block)
    end
  
    def define_instance_cache(user)
      user.cached_companies do
        user.companies
      end    
    end 

    def define_model_cache(model)
      model.cached_companies do
        model.companies
      end    
    end 
end
