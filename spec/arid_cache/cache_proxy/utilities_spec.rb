require "spec_helper"

describe AridCache::CacheProxy::Utilities do
  let(:utils) { AridCache::CacheProxy::Utilities }
  
  describe 'order_by' do
    it "id column should be prefixed by the table name" do
      stub(::ActiveRecord::Base).is_mysql_adapter? { true }
      AridCache.order_by([1,2,3], Company).should =~ %r[#{Company.table_name}]
    end

    it "id column should be prefixed by the table name" do
      stub(::ActiveRecord::Base).is_mysql_adapter? { false }
      AridCache.order_by([1,2,3], Company).should =~ %r[#{Company.table_name}]
    end
  end

  describe "find_all_by_id" do
    before :each do
      @user = User.make
      @user.companies << Company.make
      @user.companies << Company.make
      Company.make # there must be more than 2 companies for it to fail
    end

    it "should maintain order" do
      @result = utils.find_all_by_id(Company, @user.companies.reverse.map(&:id))
      @result.should == @user.companies.reverse
    end

    it "should apply options" do
      @result = utils.find_all_by_id(Company, @user.companies.reverse.map(&:id),
        :limit => 1,
        :offset => 1
      )
      @result.size.should == 1
      @result.first.should == @user.companies.reverse[1]
    end
    
    it "should not fail when ids is empty" do
      lambda {
        utils.find_all_by_id(Company, []).inspect  
      }.should query(0)
    end
  end
  
  describe "collection_klass" do
    it "should return the association class name for a collection proxy" do
      utils.collection_klass(User.make.companies).should == Company
    end
  end
end
