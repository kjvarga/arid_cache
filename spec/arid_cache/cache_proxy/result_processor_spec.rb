require 'spec_helper'

describe AridCache::CacheProxy::ResultProcessor do

  def new_result(value, opts={})
    AridCache::CacheProxy::ResultProcessor.new(value, opts)
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
      @result.to_cache.should be_a(AridCache::CacheProxy::CachedResult)
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
end
