require 'spec_helper'

describe AridCache::Proxies::IdProxy do
  before :each do
    @user = User.make
    @user.companies << Company.make
  end

  it "should return ids given records" do
    AridCache::Proxies::IdProxy.for(Company).call(@user.companies).should == @user.companies.collect(&:id)
  end

  it "should return records given ids" do
    AridCache::Proxies::IdProxy.for(Company).call(@user.companies.map(&:id)).should == @user.companies.to_a
  end
end
