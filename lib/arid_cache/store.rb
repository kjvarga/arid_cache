module AridCache
  class Store < Hash
    Item = Struct.new(:cache_key, :proc, :klass, :opts)  
    
    def has?(object, key)
      self.include?(object.arid_cache_key(key))
    end
    
    # Empty the proc store
    def delete!
      delete_if { true }
    end 

    def self.instance
      @@singleton_instance ||= self.new
    end

    def find(object, key)
      self[object.arid_cache_key(key)]
    end
    
    # Store a proc
    def add(object, key, proc, opts)
      cache_key = object.arid_cache_key(key)
      self[cache_key] = AridCache::Store::Item.new(cache_key, proc, (object.is_a?(Class) ? object : object.class), opts.symbolize_keys!)
    end
    
    # Find or dynamically create a proc
    def find_or_create(object, key)
      cache_key = object.arid_cache_key(key)
      if include?(cache_key)
        self[cache_key]
      else
        self[cache_key] = AridCache::Store::Item.new(cache_key, Proc.new { object.send(key) }, (object.is_a?(Class) ? object : object.class), {})
      end
    end
    
    def initialize
    end
  end 
end