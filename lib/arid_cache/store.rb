module AridCache
  class Store < Hash
    Struct.new('Item', :cache_key, :proc, :klass)
    
    def query(key, opts={}, object=nil, &block)
      if block_given?
        store(object, key, Proc.new)
      elsif key =~ /(.*)_count$/
        if AridCache.cache.has?(object, key)
          AridCache.cache.fetch_count(object, key)
        elsif AridCache.cache.has?(object, $1)
          AridCache.cache.fetch_count(object, $1)
        elsif object.respond_to?(key) # FIXME
          AridCache.cache.store_count(find_or_create(object, key))
        elsif object.respond_to?($1) # FIXME
          AridCache.cache.store_count(find_or_create(object, $1))
        else
          raise AridCache::Error.new("#{object} doesn't respond to #{key} or #{$1}!  Cannot dynamically create query to get the count.")
        end
      elsif AridCache.cache.has?(object, key)
        AridCache.cache.fetch(object, key)
      else
        AridCache.cache.store(find_or_create(object, key))
      end
    end
    
    # Store a proc
    def store(object, key, proc)
      cache_key = object.arid_cache_key(key)
      self[cache_key] = Struct::Item.new(cache_key, proc, object.class)
    end
    
    # Find or dynamically create a proc
    def find_or_create(object, key)
      cache_key = object.arid_cache_key(key)
      if include?(cache_key)
        self[cache_key]
      else
        if object.respond_to?(key)
        self[cache_key] = Struct::Item.new(cache_key, Proc.new { object.send(key) }, object.class)
      end
    end
    
    def has?(object, key)
      self.include?(object.arid_cache_key(key))
    end
    
    # Empty the proc store
    def delete!
      delete_if { true }
    end 
  end 
end
