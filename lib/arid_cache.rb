dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'arid_cache/helpers'
require 'arid_cache/store'
require 'arid_cache/active_record'
require 'arid_cache/cache_proxy'
require 'arid_cache/railtie'

module AridCache
  extend AridCache::Helpers
  class Error < StandardError; end #:nodoc:

  def self.cache
    AridCache::CacheProxy
  end

  def self.clear_caches
    AridCache::CacheProxy.clear_caches
  end 
  
  def self.clear_class_caches(object)
    AridCache::CacheProxy.clear_class_caches(object)
  end 
      
  def self.clear_instance_caches(object)
    AridCache::CacheProxy.clear_instance_caches(object)
  end  
    
  def self.store
    AridCache::Store.instance
  end
  
  # The old method of including this module, if you don't want to
  # extend active record.  Just add 'include AridCache' to your
  # model class.
  def self.included(base)
    base.send(:include, AridCache::ActiveRecord)
  end
  
  # Initializes AridCache for Rails.
  #
  # This method is called by `init.rb`,
  # which is run by Rails on startup.
  def self.init_rails
    ::ActiveRecord::Base.send(:include, AridCache::ActiveRecord)
  end
end
