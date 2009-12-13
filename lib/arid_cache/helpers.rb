module AridCache
  module Helpers
    def self.access_cache(scope, cache_key, proc, opts={})

      # There's something in the cache
      if !(result = Rails.cache.read(cache_key)).nil?
        
        # If it's not a special CacheHash, return it
        return result unless result.is_a?(AridCache::CacheHash)
        
        # Return the records requested
        ids = opts.include?(:page) ? result.paginate(opts, proc) : result.ids
        return proc.call(ids)
      
      # Put something into the cache for the first time.
      # Also store the count if it's an Enumerable type
      else      
        records = proc.call(:all)
        cache_hash = AridCache::CacheHash.new(records)
        Rails.cache.write(cache_key, cache_hash)
        return opts.include?(:page) ? cache_hash.paginate(opts) : records
      end
    end
    
    # The key prefix is the lowercased class name for a class
    # and the cache_key for an instance
    def self.construct_key(scope, key)
      (scope.is_a?(Class) ? scope.name.downcase : scope.cache_key) + '-' + key.to_s
    end
  end   
end
