require "spec_helper"

describe AridCache::CacheProxy::Utilities do
  describe 'order_by' do
    it "id column should be prefixed by the table name" do
      stub(::ActiveRecord::Base).is_mysql_adapter? { true }
      AridCache::CacheProxy::Utilities.order_by([1,2,3], Company).should =~ %r[#{Company.table_name}]
    end

    it "id column should be prefixed by the table name" do
      stub(::ActiveRecord::Base).is_mysql_adapter? { false }
      AridCache::CacheProxy::Utilities.order_by([1,2,3], Company).should =~ %r[#{Company.table_name}]
    end
  end
end
