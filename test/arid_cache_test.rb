require File.join(File.dirname(__FILE__), 'test_helper')

class AridCacheTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
    get_user
  end
    
  test "should respond to methods" do
    assert_respond_to(User, :cache_store)
    assert_respond_to(User.first, :cache_store)
    assert_instance_of AridCache::Store, User.cache_store
    assert_same User.cache_store, User.first.cache_store
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
    assert_instance_of(Proc, User.cache_store[User.arid_cache_key('companies')].proc)
  end
  
  test "should allow me to cache on the instance" do
    assert_nothing_raised do
      define_instance_cache(@user)
    end
    assert_instance_of(Proc, @user.cache_store[@user.arid_cache_key('companies')].proc)
  end
    
  test "should raise an error on invalid dynamic caches" do
    assert_raises ArgumentError do
      @user.cached_invalid_companies
    end
  end
  
  test "should create dynamic caches given valid arguments" do
    assert_nothing_raised { @user.cached_companies }
    assert_instance_of(Proc, @user.cache_store[@user.arid_cache_key('companies')].proc)
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
     
  # test "should empty the Rails cache" do
  #   @user.cached_companies
  #   User.cached_companies
  #   assert Rails.cache.exist?(@user.arid_cache_key('companies'))
  #   assert Rails.cache.exist?(User.arid_cache_key('companies'))
  #   User.clear_cache
  #   assert Rails.cache.exist?(@user.arid_cache_key('companies'))
  #   assert Rails.cache.exist?(User.arid_cache_key('companies'))   
  # end
      
  protected

    def get_user
      @user = User.first
      @user.cache_store.delete!
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
      user.cached_companies(:per_page => 2) do
        user.companies
      end    
    end 

    def define_model_cache(model)
      model.cached_companies(:per_page => 2) do
        model.companies
      end    
    end 
end
