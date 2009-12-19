require 'arid_cache/store'
require 'arid_cache/active_record'
require 'arid_cache/cache_proxy'
require 'will_paginate'

module AridCache
  class Error < StandardError; end
  
  def self.cache
    AridCache::CacheProxy.instance
  end
  
  def self.included(base)
    base.send(:include, AridCache::ActiveRecord)
  end
end
