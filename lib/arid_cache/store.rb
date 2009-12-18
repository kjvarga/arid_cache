module AridCache
  class Store < Hash
    Struct.new('Item', :key, :proc, :klass)
    
    def query(*args)
      AridCache.query(*args)
    end
    
    def get(key)
      self[key.to_sym]
    end
    
    def add(key, proc=nil)
      key = key.to_sym
      self[key] = Struct::Item.new(key, proc) if !self.include?(key)
      self[key].proc = proc unless proc.nil?
      self[key]
    end
    
    def delete!
      delete_if { true }
    end 
  end 
end
