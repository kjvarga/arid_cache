dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'arid_cache/store'
require 'arid_cache/active_record'
require 'arid_cache/cache_proxy'

module AridCache
  class Error < StandardError; end

  def self.cache
    AridCache::CacheProxy.instance
  end

  def self.included(base)
    base.send(:include, AridCache::ActiveRecord)
  end
end
