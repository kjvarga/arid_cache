module AridCache
  class Store < Hash

    # AridCache::Store::Blueprint
    #
    # Stores options and blocks that are used to generate results for finds
    # and counts.
    Blueprint = Struct.new(:klass, :key, :opts, :proc)  do

      def initialize(klass, key, opts={}, proc=nil)
        self.key = key
        self.klass = klass
        self.proc = proc
        self.opts = opts
      end

      def klass=(object) # store the class name only
        self['klass'] = object.is_a?(Class) ? object.name : object.class.name
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

    #
    # Capture cache configurations and blocks and store them in the store.
    #
    # A block is evaluated within the scope of this class.  The blocks
    # contains calls to methods which define the caches and give options
    # for each cache.
    #
    # Don't instantiate directly.  Rather instantiate the Instance- or
    # ClassCacheConfiguration.
    Configuration = Struct.new(:klass, :global_opts)  do

      def initialize(klass, global_opts={})
        self.global_opts = global_opts
        self.klass = klass
      end

      def method_missing(key, *args, &block)
        opts = global_opts.merge(args.empty? ? {} : args.first)
        case self
        when InstanceCacheConfiguration
          AridCache.store.add_instance_cache_configuration(klass, key, opts, block)
        else
          AridCache.store.add_class_cache_configuration(klass, key, opts, block)
        end
      end
    end
    class InstanceCacheConfiguration < Configuration; end #:nodoc:
    class ClassCacheConfiguration    < Configuration; end #:nodoc:

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

    def add_instance_cache_configuration(klass, key, opts, proc)
      add_generic_cache_configuration(instance_store_key(klass, key), klass, key, opts, proc)
    end

    def add_class_cache_configuration(klass, key, opts, proc)
      add_generic_cache_configuration(class_store_key(klass, key), klass, key, opts, proc)
    end

    def add_object_cache_configuration(object, key, opts, proc)
      add_generic_cache_configuration(object_store_key(object, key), object, key, opts, proc)
    end

    def find_or_create(object, key)
      store_key = object_store_key(object, key)
      if self.include?(store_key)
        self[store_key]
      else
        self[store_key] = AridCache::Store::Blueprint.new(object, key)
      end
    end

    protected

    def add_generic_cache_configuration(store_key, *args)
      self[store_key] = AridCache::Store::Blueprint.new(*args)
    end

    def initialize
    end

    def class_store_key(klass, key);    klass.name.downcase + '-' + key.to_s; end
    def instance_store_key(klass, key); AridCache::Inflector.pluralize(klass.name.downcase) + '-' + key.to_s; end
    def object_store_key(object, key)
      case object; when Class; class_store_key(object, key); else; instance_store_key(object.class, key); end
    end
  end
end