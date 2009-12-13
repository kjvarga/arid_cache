require 'arid_cache/helpers'
require 'arid_cache/cache_hash'
require 'will_paginate'

module AridCache
  module ClassMethods
    def arid_cache(key, opts=nil, scope=self)
      cache_key = AridCache::Helpers.construct_key(scope, key).to_sym
      store = class_variable_get("@@arid_cache".to_sym)
      proc = store[cache_key]
      
      # No block given and no proc found.  Try to create a proc dynamically and then
      # use it below.
      if proc.nil? && !block_given?
        raise ArgumentError.new("Attempting to create an ARID cache dynamically, but #{scope} doens't respond to #{key}") unless scope.respond_to?(key)
        proc = store[cache_key] = Proc.new { |ids| scope.send(key).find(ids) }
      end
      
      # Block given, store it
      if block_given?
        store[cache_key] = Proc.new

      # Cache request
      else
        AridCache::Helpers.access_cache(scope, cache_key, proc, opts)
      end
    end
    
    # Replace method missing
    alias_method :replaced_method_missing, :method_missing
    def method_missing(method, *args)
      if method.to_s =~ /^cached_(.*)$/
        arid_cache($1, *(args << self))
      else
        replaced_method_missing(method, *args)
      end
    end
  end
  
  module InstanceMethods
    def arid_cache(key, opts=nil, scope=self, &query)
      self.class.arid_cache(key, nil, scope, &query)
    end
    
    # Replace method missing
    alias_method :replaced_method_missing, :method_missing
    def method_missing(method, *args)
      if method.to_s =~ /^cached_(.*)$/
        arid_cache($1, *(args << self))
      else
        replaced_method_missing(method, *args)
      end
    end      
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
    receiver.class_eval do
      @@arid_cache = {}
    end
  end
end
