require 'spec_helper'

describe AridCache::Store do
  let(:store) { AridCache::Store.instance }
  
  describe "object_store_key" do
    it "should handle anonymous classes" do
      store.send(:object_store_key, Class.new, 'key').should == 'anonymousclass-key'
    end
    
    it "should handle anonymous instances" do
      store.send(:object_store_key, Class.new.new, 'key').should == 'anonymousclasses-key'
    end
  end
end