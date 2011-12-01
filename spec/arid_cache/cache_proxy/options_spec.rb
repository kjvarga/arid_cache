require 'spec_helper'

describe AridCache::CacheProxy::Options do
  def new_options(opts={})
    AridCache::CacheProxy::Options.new(opts)
  end

  describe "defaults" do
    before :each do
      @opt = new_options
    end

    it "should have default" do
      @opt.force?.should be_false
      @opt.paginate?.should be_false
      @opt.raw?.should be_false
      @opt.count_only?.should be_false
      @opt.order_by_proc?.should be_false
      @opt.order_by_key?.should be_false
    end
  end

  it "force?" do
    new_options(:force => true).force?.should be_true
  end

  describe "paginate?" do
    it "should be true if the :page option is present" do
      new_options(:page => 1).paginate?.should be_true
      new_options(:page => nil).paginate?.should be_true
      new_options(:per_page => 1).paginate?.should be_false
      new_options(:page => 1, :per_page => 1).paginate?.should be_true
    end
  end

  it "raw?" do
    new_options(:raw => true).raw?.should be_true
  end

  it "count_only?" do
    new_options(:count_only => true).count_only?.should be_true
  end

  it "order options" do
    @opt = new_options(:order => 'key')
    @opt.order_by_key?.should be_true
    @opt.order_by_proc?.should be_false
    @opt = new_options(:order => :symbol)
    @opt.order_by_key?.should be_true
    @opt.order_by_proc?.should be_false
    @opt = new_options(:order => Proc.new {})
    @opt.order_by_key?.should be_false
    @opt.order_by_proc?.should be_true
  end

  describe "options for paginate" do
    before :each do
      @receiver_klass = Class.new do
        def self.per_page; 23; end
      end
      @result_klass = Class.new do
        def self.per_page; 17; end
      end
    end

    it "total_entries should be nil by default" do
      new_options.opts_for_paginate[:total_entries].should be_nil
    end

    it "should set total_entries to the size of the collection" do
      new_options.opts_for_paginate((1..10).to_a)[:total_entries].should == 10
    end

    it "should use find_all_by_id as the finder" do
      new_options.opts_for_paginate[:finder].should == :find_all_by_id
    end

    it "per_page should default to 30" do
      new_options.opts_for_paginate[:per_page].should == 30
    end

    it "should get per_page from the result class" do
      new_options(:result_klass => @result_klass).opts_for_paginate[:per_page].should == 17
    end

    it "should get per_page from the receiver class" do
      new_options(:receiver_klass => @receiver_klass).opts_for_paginate[:per_page].should == 23
    end

    it "should get per_page from the result class, then the receiver class" do
      new_options(
        :result_klass => @result_klass,
        :receiver_klass => @receiver_klass
      ).opts_for_paginate[:per_page].should == 17
    end

    it "should use per_page if provided" do
      new_options(
        :result_klass => @result_klass,
        :receiver_klass => @receiver_klass,
        :per_page => 3
      ).opts_for_paginate[:per_page].should == 3
    end

    it "page should default to 1 if it is nil" do
      new_options(
        :page => nil
      ).opts_for_paginate[:page].should == 1
    end
  end

  describe "proxy?" do
    it "should use proxy" do
      new_options(:proxy => :xyz).proxy?(:in).should be_true
      new_options(:proxy => :xyz).proxy?(:out).should be_true
    end

    it "should proxy in" do
      new_options(:proxy_in => :xyz).proxy?(:in).should be_true
      new_options(:proxy_in => :xyz).proxy?(:out).should be_false
    end

    it "should proxy out" do
      new_options(:proxy_out => :xyz).proxy?(:in).should be_false
      new_options(:proxy_out => :xyz).proxy?(:out).should be_true
    end
  end

  describe "proxy" do
    it "should return the proxy" do
      new_options(:proxy_in => :xyz).proxy(:in).should == :xyz
      new_options(:proxy_out => :xyz).proxy(:out).should == :xyz
      new_options(:proxy => :xyz).proxy(:in).should == :xyz
      new_options(:proxy => :xyz).proxy(:out).should == :xyz
    end
  end

  describe "deprecated raw" do
    it "should be deprecated" do
      mock(AridCache).raw_with_options { false }
      new_options(:raw => true).deprecated_raw?.should be_true
    end

    it "should not be deprecated" do
      mock(AridCache).raw_with_options { true }
      new_options(:raw => true).deprecated_raw?.should be_false
    end
  end

  describe "receiver_klass" do
    it "should be the class of the receiver" do
      new_options(:receiver_klass => User)[:receiver_klass].should be(User)
    end
  end

  describe "opts_for_find" do
    it "should not include an order option when ordering by proc" do
      with_order_in_memory(true, false) do
        new_options(:order => Proc.new {}).opts_for_find([1,2]).should_not include(:order)
      end
    end

    it "should include an order option when ordering by SQL" do
      with_order_in_memory(true, false) do
        new_options(:order => 'played DESC').opts_for_find([1,2]).should include(:order => 'played DESC')
      end
    end

    it "should not include order option when ordering in memory" do
      with_order_in_memory(true) do
        new_options.opts_for_find([1,2]).should_not include(:order)
      end
    end

    it "should order by id in the database" do
      mock(AridCache).order_by([1,2], nil) { 'order clause'}
      with_order_in_memory(false) do
        new_options.opts_for_find([1,2]).should include(:order => 'order clause')
      end
    end
  end
end
