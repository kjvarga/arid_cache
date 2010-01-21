require File.join(File.dirname(__FILE__), 'test_helper')

class AridCacheTest < ActiveSupport::TestCase
  def setup
    FileUtils.rm_r(Rails.cache.cache_path) if File.exists?(Rails.cache.cache_path)
    @user = User.first
  end

  test "initializes needed objects" do
    assert_instance_of AridCache::Store, AridCache.store
    assert_same AridCache::CacheProxy, AridCache.cache
  end
      
  test "should respond to methods" do
    assert User.respond_to?(:clear_caches)
    assert @user.respond_to?(:clear_caches)    
    assert_instance_of AridCache::Store, AridCache.store
    assert_same AridCache::CacheProxy, AridCache.cache
  end
    
  test "should not clobber model methods" do
    assert_respond_to @user, :name
    assert_respond_to Company.first, :name
    assert_nothing_raised { @user.name }
    assert_nothing_raised { Company.first.name }
  end
  
  test "should not clobber method_missing" do
    assert_nothing_raised { @user.is_high? }
    assert @user.is_high?  
  end
     
  test "should not clobber respond_to?" do
    assert @user.respond_to?(:respond_not_overridden)
  end
     
  test "should raise an error on invalid dynamic caches" do
    assert_raises ArgumentError do
      @user.cached_invalid_companies
    end
  end
  
  test "should create dynamic caches given valid arguments" do
    assert_nothing_raised { @user.cached_companies }
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
    results = @user.cached_companies(:page => 1, :per_page => 3, :order => 'name desc')
    assert_kind_of WillPaginate::Collection, results
    assert_equal 3, results.size
    assert_equal @user.companies.count, results.total_entries
    assert_equal 1, results.current_page
  end
  
  test "should work for different pages" do
    results = @user.cached_companies(:page => 2, :per_page => 3)
    assert_kind_of WillPaginate::Collection, results
    assert results.size <= 3
    assert_equal @user.companies.count, results.total_entries  
    assert_equal 2, results.current_page  
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
    count = @user.companies.count
    assert_queries(1) do
      assert_equal count, @user.cached_companies_count
      assert_equal count, @user.cached_companies_count
    end
    assert_queries(1) do
      assert_equal count, @user.cached_companies.size
      assert_equal count, @user.cached_companies_count
    end
  end
  
  test "applies limit and offset" do
    result = @user.cached_limit_companies do
      companies
    end
    limit_two_result = @user.cached_limit_companies(:limit => 2)
    assert_equal 2, limit_two_result.size
    assert_equal result[0, 2], limit_two_result
    
    limit_three_result = @user.cached_limit_companies(:limit => 3)
    assert_equal 3, limit_three_result.size
    assert_equal result[0, 3], limit_three_result
  
    limit_two_offset_one_result = @user.cached_limit_companies(:limit => 2, :offset => 1)
    assert_equal 2, limit_two_offset_one_result.size
    assert_equal result[1, 2], limit_two_offset_one_result
    
    offset_one_result = @user.cached_limit_companies(:offset => 1)
    assert_equal result.size-1, offset_one_result.size
    assert_equal result[1, result.size], offset_one_result
            
    assert_equal @user.companies.all(:limit => 2, :offset => 1), @user.cached_limit_companies(:limit => 2, :offset => 1)
    assert_equal @user.companies.size, @user.cached_limit_companies.size    
    
    # Careful of this Rails bug: https://rails.lighthouseapp.com/projects/8994/tickets/1349-named-scope-with-group-by-bug
    User.cached_successful_limit_companies do
      User.successful.all
    end
    assert_equal 2, User.cached_successful_limit_companies(:limit => 2).size
    assert_equal 3, User.cached_successful_limit_companies(:limit => 3).size
    assert_equal User.successful.all(:limit => 2, :offset => 1), User.cached_successful_limit_companies(:limit => 2, :offset => 1)
    assert_equal User.successful.all.size, User.cached_successful_limit_companies.size  
  end
  
  test "should requery the database for limits with order" do
    @user.cached_companies # prime the cache
    assert_equal @user.companies.find(:all, :limit => 3, :order => 'name DESC'), @user.cached_companies(:limit => 3, :order => 'name DESC')
    assert_equal @user.companies.find(:all, :limit => 3, :order => 'name ASC'), @user.cached_companies(:limit => 3, :order => 'name ASC')
  end
  
  test "should activate will paginate" do
    assert_nothing_raised do
      User.paginate(:page => 1)
    end
  end
  
  test "should requery the database for paginate with order" do
    @user.cached_companies # prime the cache
    assert_equal @user.companies.paginate(:page => 1, :per_page => 3, :order => 'name DESC'), @user.cached_companies(:page => 1, :per_page => 3, :order => 'name DESC')
    assert_equal @user.companies.paginate(:page => 1, :per_page => 3, :order => 'name ASC'), @user.cached_companies(:page => 1, :per_page => 3, :order => 'name ASC')
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
  
  test "should handle arrays of non-active record instances" do
    assert_equal @user.pet_names, @user.cached_pet_names
    assert_equal @user.pet_names, @user.cached_pet_names
    assert_equal @user.pet_names.count, @user.cached_pet_names_count
  end
             
  test "should empty the Rails cache" do
    @user.cached_companies
    User.cached_companies
    assert Rails.cache.exist?(@user.arid_cache_key('companies'))
    assert Rails.cache.exist?(User.arid_cache_key('companies'))
    User.clear_caches
    assert !Rails.cache.exist?(@user.arid_cache_key('companies'))
    assert !Rails.cache.exist?(User.arid_cache_key('companies'))   
  end
  
  test "should support expiring caches" do
    # The first query should put the count in the cache.  The second query
    # should read the count from the cache.  The third query should
    # reload the cache.
    assert_queries(2) do
      User.cached_companies_count(:expires_in => 1.second)
      User.cached_companies_count(:expires_in => 1.second)
      sleep(1)
      User.cached_companies_count(:expires_in => 1.second)
    end
  end
  
  test "should support an auto-expire option" do
    assert_match %r[users/#{@user.id}-companies], @user.arid_cache_key('companies')
    assert_equal @user.arid_cache_key('companies'), @user.arid_cache_key('companies', :auto_expire => false)
    assert_match %r[users/#{@user.id}-\d{14}-companies], @user.arid_cache_key('companies', :auto_expire => true)
    
    # It doesn't apply to class caches, but shouldn't affect it either
    assert_equal User.arid_cache_key('companies'), User.arid_cache_key('companies', :auto_expire => true)
  end
  
  test "should turn off auto-expire by default" do
    assert_queries(2) do
      @user.cached_companies_count
      @user.touch
      @user.cached_companies_count
    end
  end
  
  test "should reload auto-expired caches" do
    assert_queries(2) do
      @user.cached_companies_count(:auto_expire => true)
      @user.cached_companies_count(:auto_expire => true)
      @user.updated_at = Time.now + 1.seconds
      @user.cached_companies_count(:auto_expire => true)
      @user.cached_companies_count(:auto_expire => true)
    end
  end
        
  test "should support configuring instance caches" do
    User.instance_caches { best_companies { companies } }
    assert_equal @user.companies, @user.cached_best_companies
  end
  
  test "instance caches should work on all instances of the class" do
    User.instance_caches { best_companies { companies } }
    assert_equal @user.cached_best_companies, User.first.cached_best_companies
  end
  
  test "should support configuring class caches" do
    User.class_caches { successful_users { successful } }
    assert_equal User.successful, User.cached_successful_users
  end
  
  test "should create valid store keys" do
    assert_equal 'user-key', AridCache.store.send(:class_store_key, User, 'key')
    assert_equal 'users-key', AridCache.store.send(:instance_store_key, User, 'key')
    assert_equal AridCache.store.send(:instance_store_key, User, 'key'), AridCache.store.send(:object_store_key, @user, 'key')
    assert_equal AridCache.store.send(:class_store_key, User, 'key'), AridCache.store.send(:object_store_key, User, 'key')
  end
  
  test "configuring caches should not perform any queries" do
    User.instance_caches do
      best_companies { companies }
    end
    User.class_caches do
      best_companies(:order => 'name DESC') { companies.find(:all, :order => 'name DESC') }
    end
  end
  
  test "should support options in the cache configuration" do
    User.instance_caches(:auto_expire => true) do
      expires_in = 1.second
      best_companies(:expires_in => expires_in) { companies }
    end
    assert_queries(2) do
      @user.cached_best_companies_count
      @user.updated_at = Time.now + 1.seconds
      @user.cached_best_companies_count
      @user.cached_best_companies_count
    end
    User.class_caches do
      most_successful(:order => 'name DESC') { successful.find(:all, :order => 'name DESC') }
    end
    # Call it twice to ensure that on the second call the order is applied when retrieving the
    # records by id
    assert_equal User.successful.find(:all, :order => 'name DESC'), User.cached_most_successful
    assert_equal User.successful.find(:all, :order => 'name DESC'), User.cached_most_successful   
  end
  
  test "should not raise an error if all cached ids cannot be found" do
    @user.cached_companies
    key = @user.arid_cache_key('companies')
    cached_result = Rails.cache.read(key)
    cached_result.ids.push(24342234, 243234132)
    Rails.cache.write(key, cached_result)
    assert_nothing_raised { @user.cached_companies }
    assert_equal @user.cached_companies, @user.companies
  end
  
  test "should not raise an error if all cached ids cannot be found while paginating" do
    @user.cached_companies
    key = @user.arid_cache_key('companies')
    cached_result = Rails.cache.read(key)
    cached_result.ids.push(24342234, 243234132)
    Rails.cache.write(key, cached_result)
    assert_nothing_raised { @user.cached_companies(:page => 1, :order => 'name DESC') }
    assert_equal @user.cached_companies(:page => 1, :order => 'name DESC'), @user.companies.paginate(:page => 1, :order => 'name DESC')
  end
  
  test "should handle empty collections" do
    @user.cached_empty_collection { [] }
    assert_nothing_raised { @user.cached_empty_collection }
    assert_nothing_raised { @user.cached_empty_collection }
  end

  test "should return proper paginate results when we include order" do
    total = @user.companies.count
    assert_queries(2) do
      @user.cached_companies
      page = @user.cached_companies(:page => 2, :per_page => 3, :order => 'name desc') # call again to get cached results
      assert_equal total,          page.total_entries
      assert_equal 2,              page.current_page
      assert_equal (total/3.0).ceil, page.total_pages
    end
  end
                  
  #
  # Tests requiring manual verification by looking at the SQL logs.
  # TODO move these to a separate class.
  #
   
  test "should preserve original ordering" do
    # TODO.  This one is hard to test because SQL usually keeps the same ordering
    # and it's difficult to make it do otherwise.  Best to just inspect the queries
    # in the log.
    @user.cached_companies
    @user.cached_companies
  end
  
  test "should paginate collections in memory" do
    # TODO.  Tough to test because we can't just count queries
    # have to look at the SQL in the logs for this one.
    @user.cached_companies(:page => 2, :per_page => 3)
    @user.cached_companies(:page => 1, :per_page => 3)
  end  

  protected

    def assert_queries(num = 1)
      $query_count = 0
      yield
    ensure
      assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
    end

    def assert_no_queries(&block)
      assert_queries(0, &block)
    end
end
