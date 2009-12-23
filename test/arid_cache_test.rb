require File.join(File.dirname(__FILE__), 'test_helper')

class AridCacheTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
    AridCache.store.delete!
    get_user
  end

  test "initializes needed objects" do
    assert_instance_of AridCache::Store, AridCache.store
    assert_instance_of AridCache::CacheProxy, AridCache.cache
  end
      
  test "should respond to methods" do
    assert User.respond_to?(:clear_cache)
    assert User.first.respond_to?(:clear_cache)    
    assert_instance_of AridCache::Store, AridCache.store
  end
    
  test "should not clobber model methods" do
    assert_respond_to User.first, :name
    assert_respond_to Company.first, :name
    assert_nothing_raised { User.first.name }
    assert_nothing_raised { Company.first.name }
    
    # Shouldn't mess with your model's method_missing
    assert_nothing_raised { User.first.is_high? }
    assert User.first.is_high?  
  end
    
  test "should allow me to cache on the model" do
    assert_nothing_raised do
      define_model_cache(User)
    end
    assert_instance_of(Proc, AridCache.store[User.arid_cache_key('companies')].proc)
  end
  
  test "should allow me to cache on the instance" do
    assert_nothing_raised do
      define_instance_cache(@user)
    end
    assert_instance_of(Proc, AridCache.store[@user.arid_cache_key('companies')].proc)
  end
    
  test "should raise an error on invalid dynamic caches" do
    assert_raises ArgumentError do
      @user.cached_invalid_companies
    end
  end
  
  test "should create dynamic caches given valid arguments" do
    assert_nothing_raised { @user.cached_companies }
    assert_instance_of(Proc, AridCache.store[@user.arid_cache_key('companies')].proc)
  end
  
  test "counts queries correctly" do
    assert_queries(1) { User.all }
  end
  
  test "returns valid results" do
    @one = @user.cached_companies
    assert_equal @user.companies, @one
    assert_equal @user.companies.count, @one.size
  end
  
  test "paginates results" do
    results = @user.cached_companies(:page => 1)
    assert_kind_of WillPaginate::Collection, results
    assert_equal 2, results.size
    assert_equal @user.companies.count, results.total_entries
    assert_equal 1, results.current_page
  end
  
  test "overrides default paginate options" do
    results = @user.cached_companies(:page => 1, :per_page => 3)
    assert_kind_of WillPaginate::Collection, results
    assert_equal 3, results.size
    assert_equal @user.companies.count, results.total_entries    
  end
  
  test "works for different pages" do
    results = @user.cached_companies(:page => 2, :per_page => 3)
    assert_kind_of WillPaginate::Collection, results
    assert_equal (@user.companies.count-3)%3, results.size
    assert_equal @user.companies.count, results.total_entries    
  end
  
  test "ignores random parameters" do
    result = @user.cached_companies(:invalid => :params, 'random' => 'values', :user_id => 3)
    assert_equal @user.companies, result
  end
  
  test "passes on options to find" do
    actual = @user.cached_companies(:order => 'users.id DESC')
    expected = @user.companies
    assert_equal expected, actual
    assert_equal expected.first, actual.first
  end
    
  test "caches the count when it gets records" do
    assert_queries(1) do
      @user.cached_companies
      @user.cached_companies_count
    end
  end
        
  test "gets the count only if it's requested first" do
    assert_queries(1) do
      assert_equal 5, @user.cached_companies_count
      assert_equal 5, @user.cached_companies_count
    end
    assert_queries(1) do
      assert_equal 5, @user.cached_companies.size
      assert_equal 5, @user.cached_companies_count
    end
  end
  
  test "calling cache_ defines methods on the object" do
    assert !User.method_defined?(:cached_favorite_companies)
    User.cache_favorite_companies(:order => 'name DESC') do
      User.companies
    end
    assert User.respond_to?(:cached_favorite_companies)
    assert_nothing_raised do
      User.method(:cached_favorite_companies)
    end    
  end
  
  test "pagination should not result in an extra query" do
    assert_queries(1) do
      @user.cached_big_companies(:page => 1)
    end
    assert_queries(1) do
      User.cached_companies(:page => 1)
    end
  end
  
  test "should support a 'force' option" do
    # ActiveRecord caches the result of the proc, so we need to
    # use different instances of the user to test the force option.
    uncached_user = User.first
    companies = @user.companies
    size = companies.size
    assert_queries(1) do
      assert_equal companies, @user.cached_companies
      assert_equal size, @user.cached_companies_count
      assert_equal size, uncached_user.cached_companies_count
    end
    assert_queries(2) do
      assert_equal companies, uncached_user.cached_companies(:force => true)
      assert_equal size, uncached_user.cached_companies_count(:force => true)
    end
  end
  
  test "should handle various different model instances" do
    one = User.first
    two = User.first :offset => 1
    assert_not_same one, two
    assert_equal one.companies, one.cached_companies
    assert_equal two.companies, two.cached_companies
  end
           
  test "should empty the Rails cache" do
    define_model_cache(User)
    @user.cached_companies
    User.cached_companies
    assert Rails.cache.exist?(@user.arid_cache_key('companies'))
    assert Rails.cache.exist?(User.arid_cache_key('companies'))
    User.clear_cache
    assert Rails.cache.exist?(@user.arid_cache_key('companies'))
    assert Rails.cache.exist?(User.arid_cache_key('companies'))   
  end
      
  protected

    def get_user
      @user = User.first
      @user.clear_cache
      define_instance_cache(@user)
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
      user.cache_companies(:per_page => 2) do
        user.companies
      end    
    end 

    def define_model_cache(model)
      model.cache_companies(:per_page => 2) do
        model.companies
      end    
    end 
end
