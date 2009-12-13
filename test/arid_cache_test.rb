require 'test_helper'

class AridCacheTest < ActiveSupport::TestCase
  test "should define methods on the model" do
    assert_respond_to(User, :arid_cache)
  end
  
  test "should define methods on the instance" do
    assert_respond_to(User.first, :arid_cache)
  end  

  test "should store procs" do
    assert_nothing_raised { User.send(:class_variable_get, :@@arid_cache) }
  end 
    
  test "should not clobber method_missing" do
    assert_respond_to User.first, :name
  end 

  test "should allow access to valid methods" do
    assert_nothing_raised { User.first.is_high? }
    assert User.first.is_high?
  end 
    
  test "should allow me to cache on the model" do
    assert_nothing_raised do
      define_model_cache(User)
    end
    cache = User.send(:class_variable_get, :@@arid_cache)
    assert_instance_of(Proc, cache[:'user-companies'])
  end

  test "should allow me to cache on the instance" do
    user = User.first
    assert_nothing_raised do
      define_instance_cache(user)
    end
    cache = user.class.send(:class_variable_get, :@@arid_cache)
    assert_instance_of(Proc, cache[:"#{user.cache_key}-companies"])
  end
    
  test "should raise an error on invalid dynamic caches" do
    user = User.first
    assert_raises ArgumentError do
      user.cached_invalid_companies
    end
  end

  test "should create dynamic caches given valid arguments" do
    user = User.first
    reset_cache(user)
    assert_nothing_raised { user.cached_companies }
    cache = user.class.send(:class_variable_get, :@@arid_cache)
    assert_instance_of(Proc, cache[:"#{user.cache_key}-companies"])
    puts $query_count
  end
    
  def reset_cache(user)
    user.class.send(:class_variable_set, :@@arid_cache, {})
  end
  
  def define_instance_cache(user)
    user.arid_cache(:companies) do |ids|
      user.companies.find(ids)
    end    
  end 

  def define_model_cache(model)
    model.arid_cache(:companies) do |ids|
      model.companies.find(ids)
    end    
  end 
end
