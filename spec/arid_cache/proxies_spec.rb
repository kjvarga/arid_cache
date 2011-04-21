require 'spec_helper'

describe AridCache::Proxies::IdProxy do
  before :each do
    @user = User.make
    @user.companies << Company.make               
    @ids = @user.companies.map(&:id)
  end

  it "should return ids given records" do
    AridCache::Proxies::IdProxy.for(Company).call(@user.companies).should == @ids
  end

  it "should return records given ids" do
    AridCache::Proxies::IdProxy.for(Company).call(@ids).should == @user.companies.to_a
  end 
  
  it "should accept options to find" do
    result = AridCache::Proxies::IdProxy.for(Company, :order => 'id DESC', :include => :owner).call(@ids)
    result.should == @user.companies.reverse
    lambda {
      result.collect(&:owner)
    }.should query(0)
  end
end
