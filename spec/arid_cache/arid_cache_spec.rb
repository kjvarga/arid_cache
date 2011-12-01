require 'spec_helper'

describe AridCache do
  describe 'results' do
    before :each do
      Company.destroy_all
      @company1 = Company.make(:name => 'a')
      @company2 = Company.make(:name => 'b')
      Company.class_caches do
        ordered_by_name { Company.all(:order => 'name ASC') }
      end
      Company.clear_caches
    end

    it "order should match the original order" do
      3.times do |t|
        results = Company.cached_ordered_by_name
        results.size.should == 2
        results[0].name.should == @company1.name
        results[1].name.should == @company2.name
      end
    end

    it "order should match the order option" do
      3.times do |t|
        results = Company.cached_ordered_by_name(:order => 'name DESC')
        results.size.should == 2
        results[0].name.should == @company2.name
        results[1].name.should == @company1.name
      end
    end

    it "with order option should go to the database to order" do
      lambda {
        Company.cached_ordered_by_name(:order => 'name DESC').inspect
      }.should query(2)
    end

    it "should apply limit *before* going to the database when the result is cached and no order is specified" do
      Company.cached_ordered_by_name
      id = @company1.id
      lambda {
        Company.cached_ordered_by_name(:limit => 1).inspect
      }.should query("SELECT  \"companies\".* FROM \"companies\"  WHERE (\"companies\".id in (#{id})) ORDER BY CASE WHEN \"companies\".id=#{id} THEN 1  END LIMIT 1")
    end

    it "should apply limit after going to the database when an order is specified" do
      Company.cached_ordered_by_name
      lambda {
        Company.cached_ordered_by_name(:limit => 1, :order => 'name DESC').inspect
      }.should query("SELECT  \"companies\".* FROM \"companies\"  WHERE (\"companies\".id in (#{@company1.id},#{@company2.id})) ORDER BY name DESC LIMIT 1")
    end
  end

  it "should set the special raw flag" do
    AridCache.raw_with_options.should be_false
    AridCache.raw_with_options = true
    AridCache.raw_with_options.should be_true
  end

  describe "pagination" do
    before :each do
      @user = User.make
      @user.companies << Company.make
    end

    it "should not fail if the page is nil" do
      lambda {
        @user.cached_companies(:page => nil)
        @user.cached_companies(:page => nil) # works when seeding, so call again to load from cache
      }.should_not raise_error(WillPaginate::InvalidPage)
    end
  end
end
