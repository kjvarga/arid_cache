module AridCache
  class Store < Hash
    extend ActiveSupport::Memoizable
    
    # AridCache::Store::Blueprint
    #
    # Stores options and blocks that are used to generate results for finds
    # and counts.
    Blueprint = Struct.new(:key, :klass, :proc, :opts)  do

      def initialize(key, klass, proc=nil, opts={})
        self.key = key
        self.klass = klass
        self.proc = proc
        self.opts = opts
      end
            
      def klass=(value) # store the base class of *value*
        self['klass'] = value.is_a?(Class) ? value.name : value.class.name
      end
      
      def klass
        self['klass'].constantize unless self['klass'].nil?
      end 
      
      def opts=(value)
        self['opts'] = value.symbolize_keys! unless !value.respond_to?(:symbolize_keys)
      end    
      
      def opts
        self['opts'] || {}
      end
      
      def proc(object=nil)
        if self['proc'].nil? && !object.nil?
          self['proc'] = key
        else
          self['proc']
        end
      end 
    end
    
    def has?(object, key)
      self.include?(object_store_key(object, key))
    end
    
    # Empty the proc store
    def delete!
      delete_if { true }
    end 

    def self.instance
      @@singleton_instance ||= self.new
    end

    def find(object, key)
      self[object_store_key(object, key)]
    end
    
    def add(object, key, proc, opts)
      store_key = object_store_key(object, key)
      self[store_key] = AridCache::Store::Blueprint.new(key, object, proc, opts)
    end
    
    def find_or_create(object, key)
      store_key = object_store_key(object, key)
      if self.include?(store_key)
        self[store_key]
      else
        self[store_key] = AridCache::Store::Blueprint.new(key, object)
      end
    end
    
    protected
    
    def initialize
    end
    
    def object_store_key(object, key)
      (object.is_a?(Class) ? object.name.downcase : object.class.name.pluralize.downcase) + '-' + key.to_s
    end
    memoize :object_store_key
  end 
end