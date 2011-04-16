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

  it "paginate?" do
    new_options(:page => 1).paginate?.should be_true
    new_options(:per_page => 1).paginate?.should be_false
    new_options(:page => 1, :per_page => 1).paginate?.should be_true
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
  end

  describe "proxies" do
    it "should use proxy" do
      new_options(:proxy => :serializing_proxy).proxy?.should be_true
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
end
