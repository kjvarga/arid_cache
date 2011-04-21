dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'arid_cache/helpers'
require 'arid_cache/store'
require 'arid_cache/active_record'
require 'arid_cache/cache_proxy'
require 'arid_cache/railtie' if defined?(Rails)
require 'arid_cache/inflector'
require 'arid_cache/framework'
require 'arid_cache/proxies'

module AridCache
  extend AridCache::Helpers
  extend AridCache::CacheProxy::Utilities

  Error = Class.new(StandardError) #:nodoc:

  class << self
    attr_accessor :framework
  end

  # Set to true to make the :raw option return ids after applying options to them.
  # The deprecated behaviour is to return a CachedResult and ignore all options.
  def self.raw_with_options=(value)
    @raw_with_options = value
  end

  def self.raw_with_options
    !!@raw_with_options
  end

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

  def self.version
    @version ||= File.read(File.join(File.dirname(__FILE__), '..', 'VERSION')).strip
  end

  self.framework = AridCache::Framework.new
end
