module AridCache
  module Helpers
    # *count* whether or not to return the record count (ignores *opts*)
    def self.access_cache(scope, cache_key, proc, opts={}, count=false)

      # There's something in the cache
      if !(result = Rails.cache.read(cache_key)).nil?
        
        # If it's not a special CacheHash, return it
        return result unless result.is_a?(AridCache::CacheHash)
        
        # Return the records requested
        if count
          return result.ids.size
        else
          ids = opts.include?(:page) ? result.paginate(opts, proc) : result.ids
          return proc.call(ids)
        end
      
      # Put something into the cache for the first time.
      # Also store the count if it's an Enumerable type
      else      
        records = proc.call(:all)
        cache_hash = AridCache::CacheHash.new(records)
        Rails.cache.write(cache_key, cache_hash)
        Rails.cache.write(cache_key.to_s + '_count', records.size) if records.is_a?(Enumerable)
        if count
          return records.size
        else
          return opts.include?(:page) ? cache_hash.paginate(opts) : records
        end
      end
    end
    
    # The key prefix is the lowercased class name for a class
    # and the cache_key for an instance
    def self.construct_key(scope, key, suffix=nil)
      cache_key = (scope.is_a?(Class) ? scope.name.downcase : scope.cache_key) + '-' + key.to_s
      suffix.nil? ? cache_key : cache_key + suffix
    end
  end   
end
