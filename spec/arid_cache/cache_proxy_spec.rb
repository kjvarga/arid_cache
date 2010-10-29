require 'spec_helper'

describe AridCache::CacheProxy do
  describe 'id in order clause' do
    before :each do
      @proxy = AridCache::CacheProxy.new(Company, 'dummy-key', {})
    end
    
    it "should be prefixed by the table name" do
      ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(true)
      @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
    end
    
    it "should be prefixed by the table name" do
      ::ActiveRecord::Base.stubs(:is_mysql_adapter?).returns(false)
      @proxy.send(:preserve_order, [1,2,3]).should =~ %r[#{Company.table_name}]
    end
  end
end