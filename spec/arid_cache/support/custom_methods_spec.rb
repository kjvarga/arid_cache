require "spec_helper"

describe CustomMethods do
  describe "with_order_in_memory" do
    it "should set order_in_memory to true" do
      with_order_in_memory do
        AridCache.order_in_memory?.should be_true
      end
    end
  end
end
