module AridCache
  class Store < Hash
    Struct.new('Item', :cache_key, :proc, :klass)
    
    def query(key, opts, object, &block)
      if block_given? # store a proc
        store(object, key, Proc.new)
      elsif has?(object, key) # use the proc we have
        AridCache.cache.fetch(find_or_create(object, key))
      elsif key =~ /(.*)_count$/ # dynamic count
        if object.respond_to?(key)
          AridCache.cache.fetch_count(find_or_create(object, key))            
        elsif object.respond_to?($1)
          AridCache.cache.fetch_count(find_or_create(object, $1))
        else
          raise AridCache::Error.new("#{object} doesn't respond to #{key} or #{$1}!  Cannot dynamically create query to get the count.")
        end
      else # dynamic find
        AridCache.cache.fetch(find_or_create(object, key), opts)
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