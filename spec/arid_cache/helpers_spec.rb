require 'spec_helper'

describe AridCache::Helpers do
  describe "subclasses_of" do
    before :each do
      class Aa; end
      class Bb < Aa; end
      class Cc < Bb; end
    end
    
    it "should description" do
      AridCache.subclasses_of(Aa).should == [Cc, Bb]
      AridCache.subclasses_of(Bb).should == [Cc]
    end
  end
end