require 'spec_helper'

describe AridCache::Helpers do
  describe "subclasses_of" do
    before :each do
      class Aa; end
      class Bb < Aa; end
      class Cc < Bb; end
    end
    
    it "should description" do
      AridCache.subclasses_of(Aa).should include(Cc)
      AridCache.subclasses_of(Aa).should include(Bb)
      AridCache.subclasses_of(Bb).should == [Cc]
    end
  end
  
  describe "class_name" do
    it "should return the class name given a class" do
      class Xyz; end
      AridCache.class_name(Xyz).should == 'Xyz'
      AridCache.class_name(Xyz, :pluralize).should == 'Xyzs'
      AridCache.class_name(Xyz, :downcase).should == 'xyz'
      AridCache.class_name(Xyz, :downcase, :pluralize).should == 'xyzs'
    end

    it "should return the class name given an instance of a class" do
      class Xyz; end
      obj = Xyz.new
      AridCache.class_name(obj).should == 'Xyz'
      AridCache.class_name(obj, :pluralize).should == 'Xyzs'
      AridCache.class_name(obj, :downcase).should == 'xyz'
      AridCache.class_name(obj, :downcase, :pluralize).should == 'xyzs'
    end

    it "should raise on invalid modifier" do
      lambda { AridCache.class_name(Class, :invalid) }.should raise_error(ArgumentError)
    end
    
    it "should return a suitable name for anonymous classes" do
      x = Class.new.new
      AridCache.class_name(x).should == 'AnonymousClass'
      AridCache.class_name(x, :pluralize).should == 'AnonymousClasses'
      AridCache.class_name(x, :downcase).should == 'anonymousclass'
      AridCache.class_name(x, :downcase, :pluralize).should == 'anonymousclasses'      
    end
  end
end