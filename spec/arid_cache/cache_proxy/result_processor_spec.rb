require 'spec_helper'

describe AridCache::CacheProxy::ResultProcessor do

  def new_result(value, opts={})
    AridCache::CacheProxy::ResultProcessor.new(value, opts)
  end

  # Yield the block once with raw_with_options off, and once with raw_with_options on.
  # The block should make RSpec assertions.
  def with_deprecated_support
    current = AridCache.raw_with_options
    yield
    AridCache.raw_with_options = !!current
    yield
    AridCache.raw_with_options = current
  end

  before :each do
    AridCache.raw_with_options = true
  end

  describe "empty array" do
    before :each do
      @result = new_result([])
    end

    it "should recognize an empty array" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_true
      @result.is_activerecord?.should be_false
      @result.is_hashes?.should be_false
      @result.is_cached_result?.should be_false
      @result.order_in_database?.should be_false
    end

    it "should return an empty array from the cache" do
      with_deprecated_support {
        result = new_result(@result.to_cache).to_result
        result.should be_a(Array)
        result.should be_empty
      }
    end

    describe "with deprecated raw handling" do
      before :each do
        AridCache.raw_with_options = false
      end

      it "should be cached as a CachedResult" do
        @result.to_cache.should be_a(AridCache::CacheProxy::CachedResult)
      end

      it "with :raw => true should return a CachedResult" do
        new_result(@result.to_cache, :raw => true).to_result.should be_a(AridCache::CacheProxy::CachedResult)
      end
    end

    describe "with new raw handling" do
      before :each do
        AridCache.raw_with_options = true
      end

      it "should be cached as an Array" do
        @result.to_cache.should be_a(Array)
      end

      it "with :raw => true should return an Array" do
        new_result(@result.to_cache, :raw => true).to_result.should be_a(Array)
      end
    end

    describe "when proxied" do
      before :each do
        @user = User.make
      end

      it "in should store result unmodified" do
        @proxy = Proc.new { |ids| ids.should be_a(Array); ids }
        with_deprecated_support {
          @user.cached_empty_array_in(:proxy_in => @proxy, :force => true) { [] }.should be_a(Array)
          @user.cached_empty_array_in.should be_a(Array)
          @user.cached_empty_array_in(:raw => true).should be_a(Array)
        }
      end

      it "out should pass the ids not a CachedResult" do
        @proxy = Proc.new { |ids| ids.should be_a(Array); ids }
        with_deprecated_support {
          @user.cached_empty_array_out(:proxy_out => @proxy, :force => true) { [] }.should be_a(Array)
          @user.cached_empty_array_out.should be_a(Array)
          @user.cached_empty_array_out(:raw => true).should be_a(Array)
        }
      end
    end
  end

  describe "basic array" do
    before :each do
      @result = new_result([1,2,3])
    end

    it "should recognize an empty array" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_false
      @result.is_activerecord?.should be_false
      @result.is_hashes?.should be_false
      @result.is_activerecord_reflection?.should be_false
      @result.order_in_database?.should be_false
      @result.to_cache.should == [1,2,3]
    end
  end

  describe "array of activerecords" do
    before :each do
      @company = Company.make
      @result = new_result([@company])
    end

    it "should recognize activerecords" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_false
      @result.is_activerecord?.should be_true
      @result.is_hashes?.should be_false
      @result.order_in_database?.should be_false
      @result.is_activerecord_reflection?.should be_false
    end

    it "should convert to a CachedResult" do
      @cached = @result.to_cache
      @cached.should be_a(AridCache::CacheProxy::CachedResult)
      @cached.ids.should == [@company.id]
      @cached.klass.should == @company.class
      @cached.count.should == 1
    end
  end

  describe "array of hashes" do
    before :each do
      @result = new_result([{}, {}])
    end

    it "should be recognized" do
      @result.is_enumerable?.should be_true
      @result.is_empty?.should be_false
      @result.is_activerecord?.should be_false
      @result.is_hashes?.should be_true
      @result.order_in_database?.should be_false
      @cached = @result.to_cache
      @cached.should == [{}, {}]
    end
  end

  describe "proxy reflections" do
    before :each do
      @user = User.make
    end

    it "should be recognized" do
      @result = new_result(@user.companies)
      @result.is_activerecord_reflection?.should be_true
    end

    it "should recognize named scope" do
      @result = new_result(User.companies)
      @result.is_activerecord_reflection?.should be_true
    end
  end

  describe "cached result" do
    before :each do
      @result = new_result(AridCache::CacheProxy::CachedResult.new)
    end

    it "should be recognized" do
      @result.is_cached_result?.should be_true
    end
  end

  describe "order in database" do
    before :each do
      @company = Company.make
      @cached = AridCache::CacheProxy::CachedResult.new
      @cached.klass = Company
      @cached.ids = [@company.id]
    end

    it "cached results should use the database for ordering" do
      @result = new_result(@cached, :order => 'column DESC')
      @result.is_cached_result?.should be_true
      @result.order_in_database?.should be_true
    end

    it "active records should use the database only if an order is specified" do
      @result = new_result([@company], :order => 'column DESC')
      @result.order_in_database?.should be_true
      @result = new_result([@company], :order => :symbol)
      @result.order_in_database?.should be_true
      @result = new_result([@company], :order => Proc.new {})
      @result.order_in_database?.should be_false
    end
  end


  describe "non-activerecord enumerables" do
    before :each do
      @value = (1..10).to_a
    end

    it "should return it unmodified" do
      new_result(@value).to_result.should == @value
    end

    it "should apply limit" do
      @limit = 3
      new_result(@value, :limit => @limit).to_result.should == @value[0,@limit]
      new_result(@value, :limit => @limit).to_result.size.should == @limit
      new_result(@value, :limit => @value.size).to_result.should == @value
      new_result(@value, :limit => 0).to_result.should == []
    end

    it "should apply offset" do
      @offset = 3
      new_result(@value, :offset => @offset).to_result.should == @value[@offset,@value.size]
      new_result(@value, :offset => @offset).to_result.size.should == @value.size - @offset
      new_result(@value, :offset => @value.size).to_result.should == []
    end

    it "should apply offset and limit" do
      @offset = 2
      @limit = 3
      new_result(@value, :offset => @offset, :limit => @limit).to_result.should == @value[@offset,@limit]
      new_result(@value, :offset => @offset, :limit => @limit).to_result.size.should == @limit
    end

    describe "order by" do
      before :each do
        @low = [1, 2, 3, 4]
        @high = [5, 6, 7, 8]
        @hashes = [{ 'low' => 4, :high => 6 }, { 'low' => 3, :high => 5 }, { 'low' => 1, :high => 8 }, { 'low' => 2, :high => 7 }]
        @value = (1..10).to_a
      end

      it "should order by proc" do
        new_result(@value, :order => Proc.new { |a, b| b <=> a }).to_result.should == @value.reverse
      end

      it "should order hashes by string key" do
        new_result(@hashes, :order => 'low').to_result.collect { |h| h['low'] }.should == @low
      end

      it "should order hashes by symbol key" do
        new_result(@hashes, :order => :high).to_result.collect { |h| h[:high] }.should == @high
      end
    end

    describe "paginating arrays" do
      before :each do
        @value = (1..10).to_a
      end

      it "should paginate" do
        @result = new_result(@value, :page => 1).to_result
        @result.should be_a(WillPaginate::Collection)
        @result.total_entries.should == @value.size
        @result.current_page.should == 1
      end

      it "should handle per_page option" do
        @result = new_result(@value, :page => 3, :per_page => 3).to_result
        @result.should be_a(WillPaginate::Collection)
        @result.total_entries.should == @value.size
        @result.current_page.should == 3
        @result.per_page.should == 3
      end
    end

    it "should order limit and then paginate all at once" do
       # It will reverse it, offset 2, limit 15, then paginate
       @options = {
         :limit => 15,
         :offset => 2,
         :order => Proc.new { |a, b| b <=> a },
         :page => 2,
         :per_page => 5
       }
       @result = new_result((1..20).to_a, @options).to_result.should == [13, 12, 11, 10, 9]
    end
  end

  describe "proxies" do
    before :each do
      class User
        instance_caches do
          companies(:proxy => :hash_proxy)
          companies_in(:proxy_in => :id_proxy) {   # store ids, return ids
            companies
          }
          companies_out(:proxy_out => :id_proxy) { # store ids, return records
            companies.all.map(&:id)
          }
        end

        def self.id_proxy(records)
          return records if records.empty?
          records.first.is_a?(ActiveRecord::Base) ? records.collect(&:id) : AridCache.find_all_by_id(Company, records)
        end

        def self.hash_proxy(records)
          return records if records.empty?
          records.first.is_a?(ActiveRecord::Base) ? records.collect(&:attributes) : records.collect { |r| Company.find_by_id(r['id']) }
        end
      end

      @user = User.make
      @company = Company.make
      @user.companies << @company
      @user.cached_companies(:clear => true)
    end

    it "the proxy called on itself should return the original value" do
      User.hash_proxy(User.hash_proxy([@company])).should == [@company]
    end

    it "the proxy called on itself should return the original value" do
      User.id_proxy(User.id_proxy([@company])).should == [@company]
    end

    it "should serialize" do
      mock.proxy(User).hash_proxy(anything)
      @user.cached_companies.should == [@company]
    end

    it "should un-serialize" do
      mock.proxy(User).hash_proxy(anything).twice
      @user.cached_companies.should == [@company] # seed the cache
      @user.cached_companies.should == [@company]
    end

    it "should return json with :raw => true" do
      mock.proxy(User).hash_proxy(anything)
      # Seed the cache; it should use the serialized result in the return value.
      value = @user.cached_companies(:raw => true)

      # Comparing the hashes directly doesn't work because the updated_at Time are
      # not considered equal...don't know why, cause the to_s looks the same.
      value.should be_a(Array)
      value.first.should be_a(Hash)
      value.first.each_pair do |k, v|
        v.to_s.should == @company.attributes[k].to_s
      end

      # Cache is seeded, it should use the cached result
      dont_allow(User).hash_proxy
      value = @user.cached_companies(:raw => true)
      value.should be_a(Array)
      value.first.should be_a(Hash)
      value.first.each_pair do |k, v|
        v.to_s.should == @company.attributes[k].to_s
      end
    end

    it "should proxy out only" do
      mock.proxy(User).id_proxy(anything)
      @user.cached_companies_out.should == @user.companies.to_a
      @user.cached_companies_out(:raw => true).should == @user.companies.map(&:id)
    end

    it "should proxy in only" do
      mock.proxy(User).id_proxy(anything)
      @user.cached_companies_in.should == @user.companies.map(&:id)
      @user.cached_companies_in(:raw => true).should == @user.companies.map(&:id)
    end

    describe "as a Proc" do
      before :each do
        @ids = [1,2,3]
        @proc = Proc.new { |records| records.reverse }
      end

      it "the proc should reverse the list" do
        #mock.proxy(@proxy).call(@ids)
        @proc.call(@ids).should == @ids.reverse
      end

      it "should be called going in" do
        #mock.proxy(@proxy).call(@ids)
        new_result(nil, :proxy_in => @proc).send(:run_user_proxy, :in, @ids).should == @ids.reverse
      end

      it "should not be called going out" do
        #mock.proxy(@proxy).call(@ids).never
        new_result(nil, :proxy_in => @proc).send(:run_user_proxy, :out, @ids).should == @ids
      end

      it "should be called going out" do
        #mock.proxy(@proxy).call(@ids)
        new_result(nil, :proxy_out => @proc).send(:run_user_proxy, :out, @ids).should == @ids.reverse
      end

      it "should not be called going in" do
        #mock.proxy(@proxy).call(@ids).never
        new_result(nil, :proxy_out => @proc).send(:run_user_proxy, :in, @ids).should == @ids
      end

      it "should be called both ways" do
        #mock.proxy(@proxy).call(anything).twice
        new_result(nil, :proxy => @proc).send(:run_user_proxy, :in, @ids).should == @ids.reverse
        new_result(nil, :proxy => @proc).send(:run_user_proxy, :out, @ids).should == @ids.reverse
      end
    end

    describe "with options" do
      before :each do
        @c2 = Company.make
        @c3 = Company.make
        @user.companies << @c2
        @user.companies << @c3
      end

      it "should apply limit and offset" do
        @companies = @user.cached_companies
        @user.cached_companies(:limit => 2, :offset => 1).should == @companies[1,2]
      end

      it "should apply limit and offset with :raw => true" do
        @companies = @user.cached_companies
        @user.cached_companies(:limit => 2, :offset => 1, :raw => true).should == User.hash_proxy(@companies[1,2])
      end

      it "should apply pagination" do
        @companies = @user.cached_companies
        value = @user.cached_companies(:page => 2, :per_page => 2)
        value.should be_a(WillPaginate::Collection)
        value.first.should be_a(Company)
        value.first.should == @companies[-1]
        value.total_entries.should == @companies.size
        value.current_page.should == 2
        value.size.should == 1
      end

      it "should get the count for free" do
        lambda { @user.cached_companies_count }.should query(1)
        lambda { @user.cached_companies_count }.should query(0)
      end

      it "should paginate with :raw => true" do
        @companies = User.hash_proxy(@user.cached_companies)
        value = @user.cached_companies(:page => 2, :per_page => 2, :raw => true)
        value.should be_a(WillPaginate::Collection)
        value.first.should be_a(Hash)
        value.first.should == @companies[-1]
        value.total_entries.should == @companies.size
        value.current_page.should == 2
        value.size.should == 1
      end

      it "should order by" do
        @companies = @user.cached_companies
        @user.cached_companies(:order => 'id').should == @companies
        @user.cached_companies(:order => Proc.new { |a, b| b['id'] <=> a['id'] }).should == @companies.reverse
      end

      it "should order by with :raw => true" do
        @companies = @user.cached_companies(:raw => true)
        @companies.first.should be_a(Hash)
        @user.cached_companies(:order => 'id', :raw => true).should == @companies
        @user.cached_companies(:order => Proc.new { |a, b| b['id'] <=> a['id'] }, :raw => true).should == @companies.reverse
      end

      it "should apply all options at once" do
        @companies = @user.cached_companies
        value = @user.cached_companies(
          :order => Proc.new { |a, b| b['id'] <=> a['id'] },
          :limit => 2, :offset => 1,
          :page => 1, :per_page => 2)
        value.should be_a(WillPaginate::Collection)
        value.current_page.should == 1
        value.total_entries.should == 2
        value.to_a.should == [@companies[1], @companies[0]]
      end

      it "should apply all options with :raw => true" do
        @companies = @user.cached_companies(:raw => true)
        value = @user.cached_companies(
          :order => Proc.new { |a, b| b['id'] <=> a['id'] },
          :limit => 2, :offset => 1,
          :page => 1, :per_page => 2,
          :raw => true)
        value.should be_a(WillPaginate::Collection)
        value.current_page.should == 1
        value.total_entries.should == 2
        value.first.should be_a(Hash)
        value.to_a.should == [@companies[1], @companies[0]]
      end
    end
  end

  describe "raw with options handling" do
    before :each do
      @user = User.make
      @company1 = Company.make
      @company2 = Company.make
      @user.companies << @company1
      @user.companies << @company2
      class User
        instance_caches do
          raw_companies(:raw => true) { companies }
        end
      end
      @user.cached_raw_companies(:clear => true)
    end

    it "should return ids" do
      @user.cached_raw_companies.should == [@company1.id, @company2.id]
    end

    it "should apply order" do
      @user.cached_raw_companies(:order => Proc.new { |a,b| b <=> a }).should == [@company2.id, @company1.id]
    end

    it "should not order in database" do
       new_result(AridCache::CacheProxy::CachedResult.new).order_in_database?.should be_true
       new_result(AridCache::CacheProxy::CachedResult.new, { :raw => true }).order_in_database?.should be_false
    end

    it "should apply offset and limit" do
      @user.cached_raw_companies(:limit => 1).should == [@company1.id]
      @user.cached_raw_companies(:offset => 1).should == [@company2.id]
    end

    it "should apply pagination" do
      value = @user.cached_raw_companies(:page => 2, :per_page => 1)
      value.should be_a(WillPaginate::Collection)
      value.total_entries.should == 2
      value.current_page.should == 2
      value.should == [@company2.id]
    end
  end

  describe "cached proxy_options result" do
    before :each do
      @user = User.make
      @obj = Array.new([@user])
      @obj.class_eval do
        def respond_to?(method)
          return true if method == :proxy_options
        end
      end
    end

    it "should store a CachedResult" do
      new_result(@obj).to_cache.should be_a(AridCache::CacheProxy::CachedResult)
    end

    it "should be a reflection" do
      new_result(@obj).is_activerecord_reflection?.should be_true
    end

    it "should not be able to infer the result klass" do
      cache = new_result(@obj).to_cache
      cache.klass.should be(NilClass)
    end
  end

  describe "cached proxy_reflection result" do
    before :each do
      @user = User.make
      @obj = Array.new([@user])
      stub(@obj).proxy_reflection { stub(Object.new).klass { Company } }
    end

    it "should be a reflection" do
      new_result(@obj).is_activerecord_reflection?.should be_true
    end

    it "should store a CachedResult" do
      new_result(@obj).to_cache.should be_a(AridCache::CacheProxy::CachedResult)
    end

    it "should set klass from the proxy_reflection" do
      cache = new_result(@obj).to_cache
      cache.klass.should be(Company)
    end
  end

  describe "deprecated" do
    before :each do
      AridCache.raw_with_options = false
    end

    describe "cached empty reflection-like result" do
      before :each do
        @user = User.make
        @obj = Array.new([])
        @obj.class_eval do
          def respond_to?(method)
            return true if method == :proxy_options
          end
        end
      end

      it "should store a CachedResult" do
        new_result(@obj).to_cache.should be_a(AridCache::CacheProxy::CachedResult)
      end

      it "should not be able to infer the class of the results (without knowing the receiver class)" do
        result = new_result(@ob)
        result.options[:receiver_klass].should be_nil
        cached = result.to_cache
        cached.klass.should be(NilClass)
      end

      it "should return an empty array" do
        result = new_result(@obj).to_result
        result.should be_a(Array)
        result.should be_empty
      end

      it "should be a reflection" do
        new_result(@obj).is_activerecord_reflection?.should be_true
      end

      it "should fall back to the receiver class" do
        cache = new_result(@obj, :receiver_klass => User).to_cache
        cache.klass.should be(User)
      end
    end
  end

  describe "result_klass" do
    before :each do
      @obj = Class.new do
        def self.per_page; 11; end
      end.new
      @options = AridCache::CacheProxy::Options.new(:receiver_klass => @obj.class)
      @result = new_result(@obj, @options)
    end

    it "the mock class should define per_page" do
      @obj.class.per_page.should == 11
    end

    it "should be the class of the receiver object" do
      @result.send(:result_klass).should == @obj.class
    end

    it "should be set on the options when fetch_activerecords is called" do
      @options[:result_klass].should == nil
      @result.send(:fetch_activerecords, [])
      @options[:result_klass].should be(@obj.class)
    end
  end

  describe "cached result with NilClass" do
    before :each do
      @cached = AridCache::CacheProxy::CachedResult.new
      @cached.klass = nil
    end

    it "should have NilClass" do
      @cached.klass.should be(NilClass)
    end

    it "should return nil if no ids" do
      with_deprecated_support {
        @cached.has_ids?.should be_false
        new_result(@cached).to_result.should be_nil
      }
    end

    it "should return empty array" do
      with_deprecated_support {
        @cached.ids = []
        @cached.has_ids?.should be_true
        result = new_result(@cached).to_result
        result.should be_a(Array)
        result.should be_empty
      }
    end
  end
end
