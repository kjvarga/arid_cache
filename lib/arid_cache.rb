require 'arid_cache/store'
require 'arid_cache/active_record'
require 'will_paginate'

module AridCache
  def self.included(base)
    base.send(:include, AridCache::ActiveRecord)
  end
  
  # Define a new cache or call an existing cache
  def self.query(key, opts={}, scope=nil, &block)
    store = scope.cache_store
    cache_key = construct_key(scope, key).to_sym
    item = store.get(cache_key)
    
    # No block given and no proc found.  Create a proc dynamically.
    if item.nil? && !block_given?
      
      # Build association_count dynamically using 'association.count' unless
      # we have a proc stored for 'association'.
      if key =~ /(.*)_count$/
        base_cache_key = construct_key(scope, $1).to_sym
        if !store.include?(base_cache_key)
          raise ArgumentError.new("Attempting to create an ARID cache dynamically, but #{scope} doesn't respond to #{$1}") unless scope.respond_to?($1)
          item = store.add(base_cache_key, Proc.new { scope.send($1).count })
        else
          item = store.get(base_cache_key)
          return access_cache(scope, base_cache_key, item.proc, opts, count=true)
        end
      else
        raise ArgumentError.new("Attempting to create an ARID cache dynamically, but #{scope} doesn't respond to #{key}") unless scope.respond_to?(key)
        item = store.add(cache_key, Proc.new { scope.send(key) })
      end
    end
    
    if block_given? # Block given, store it
      item = store.add(base_cache_key, Proc.new)
    else # Cache request
      access_cache(scope, cache_key, item.proc, opts)
    end
  end
    
  # *count* whether or not to return the record count (ignores *opts*)
  def self.access_cache(scope, cache_key, proc, opts={}, count=false)

    # There's something in the cache
    if !(result = Rails.cache.read(cache_key.to_s)).nil?
    
      # If it's not an Enumberable, return it
      return result unless result.is_a?(Enumerable)
    
      # Return the records requested
      if count
        return result.count
      else
        return opts.include?(:page) ? paginate(result, opts, proc) : proc.call(result)
      end
  
    # Put something into the cache for the first time.
    # Also store the count if it's an Enumerable type
    else      
      results = proc.call
      if !results.is_a?(Enumerable)
        Rails.cache.write(cache_key.to_s, results)
        return results
      else
        Rails.cache.write(cache_key.to_s, results.collect(&:id))
        Rails.cache.write(cache_key.to_s + '_count', results.count)
        if count
          return results.count
        else
          return opts.include?(:page) ? paginate(results, opts) : results
        end
      end
    end
  end

  # The key prefix is the lowercased class name for a class
  # and the cache_key for an instance
  def self.construct_key(scope, key, suffix=nil)
    cache_key = (scope.is_a?(Class) ? scope.name.downcase : scope.cache_key) + '-' + key.to_s
    suffix.nil? ? cache_key : cache_key + suffix
  end

  # Pass *proc* to indicate that *records* contains ids
  def self.paginate(records, opts, proc=nil) 
    if !proc.nil?
      ids = opts.include?(:page) ? records.paginate(opts) : records
      records = proc.call(ids)
      ids.is_a?(WillPaginate::Collection) ? ids.replace(records) : records
    else
      opts.include?(:page) ? records.paginate(opts) : records
    end
  end
end
