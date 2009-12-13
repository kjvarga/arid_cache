require 'arid_cache/helpers'
require 'will_paginate'

module AridCache
  module ClassMethods
    def arid_cache(key, opts={}, scope=self)
      store = class_variable_get("@@arid_cache".to_sym)
      cache_key = AridCache::Helpers.construct_key(scope, key).to_sym
      proc = store[cache_key]
      
      # No block given and no proc found.  Try to create a proc dynamically.
      if proc.nil? && !block_given?
        
        # Build association_count dynamically using 'association.count' unless
        # we have a proc stored for 'association'.
        if key =~ /(.*)_count$/
          base_cache_key = AridCache::Helpers.construct_key(scope, $1).to_sym
          if !store.include?(base_cache_key)
            raise ArgumentError.new("Attempting to create an ARID cache dynamically, but #{scope} doens't respond to #{$1}") unless scope.respond_to?($1)
            proc = store[cache_key] = Proc.new { |ids| scope.send($1).count }
          else
            proc = store[base_cache_key]
            return AridCache::Helpers.access_cache(scope, base_cache_key, proc, opts, count=true)
          end
        else
          raise ArgumentError.new("Attempting to create an ARID cache dynamically, but #{scope} doens't respond to #{key}") unless scope.respond_to?(key)
          proc = store[cache_key] = Proc.new { |ids| scope.send(key).find(ids) }
        end
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
        arid_cache($1, *args)
      else
        replaced_method_missing(method, *args)
      end
    end
  end
  
  module InstanceMethods
    def arid_cache(key, opts={}, scope=self, &query)
      self.class.arid_cache(key, opts, scope, &query)
    end
    
    # Replace method missing
    alias_method :replaced_method_missing, :method_missing
    def method_missing(method, *args)
      if method.to_s =~ /^cached_(.*)$/
        arid_cache($1, *args)
      else
        super #replaced_method_missing(method, *args)
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
