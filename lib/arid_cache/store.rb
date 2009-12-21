module AridCache
  class Store < Hash
    Struct.new('Item', :cache_key, :proc, :klass, :opts)
    
    def query(key, opts, object, &block)
      return store(object, key, Proc.new, opts) if block_given? # store a proc

      if has?(object, key)
        AridCache.cache.fetch(find(object, key), opts)
      elsif key =~ /(.*)_count$/
        if has?(object, $1)
          AridCache.cache.fetch_count(find(object, $1))
        elsif object.respond_to?(key)
          AridCache.cache.fetch_count(find_or_create(object, key))
        elsif object.respond_to?($1)
          AridCache.cache.fetch_count(find_or_create(object, $1))
        else
          raise ArgumentError.new("#{object} doesn't respond to #{key} or #{$1}!  Cannot dynamically create query to get the count.")
        end 
      else         
        if object.respond_to?(key)
          AridCache.cache.fetch(find_or_create(object, key), opts)
        else
          raise ArgumentError.new("#{object} doesn't respond to #{key}!  Cannot dynamically create query.")
        end
      end
    end
    
    # Store a proc
    def store(object, key, proc, opts)
      cache_key = object.arid_cache_key(key)
      self[cache_key] = Struct::Item.new(cache_key, proc, (object.is_a?(Class) ? object : object.class), opts.symbolize_keys!)
    end
    
    def find(object, key)
      self[object.arid_cache_key(key)]
    end
    
    # Find or dynamically create a proc
    def find_or_create(object, key)
      cache_key = object.arid_cache_key(key)
      if include?(cache_key)
        self[cache_key]
      else
        self[cache_key] = Struct::Item.new(cache_key, Proc.new { object.send(key) }, (object.is_a?(Class) ? object : object.class))
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