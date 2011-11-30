module AridCache
  module ActiveRecord
    def self.included(base)
      base.extend         ClassMethods
      base.extend         MirrorMethods
      base.send :include, MirrorMethods
    end

    module MirrorMethods
      def clear_caches
        AridCache.cache.clear_class_caches(self)
        AridCache.cache.clear_instance_caches(self)
      end

      def clear_class_caches
        AridCache.cache.clear_class_caches(self)
      end

      def clear_instance_caches
        AridCache.cache.clear_instance_caches(self)
      end

      # Return an AridCache key for the given key fragment for this object.
      #
      # Supported options:
      #   :auto_expire => true/false   # (default false) whether or not to use the <tt>cache_key</tt> method on instance caches
      #
      # == Example
      #   User.arid_cache_key('companies')       => 'arid-cache-user-companies'
      #   User.first.arid_cache_key('companies') => 'arid-cache-users/1-companies'
      #   User.first.arid_cache_key('companies', :auto_expire => true) => 'arid-cache-users/1-20090120091123-companies'
      #
      # If called on a class with two arguments, the first being a record id and the
      # second being the cache key, constructs and returns a cache key as if
      # arid_cache_key was called on the record.
      #
      # In this way, the following two calls are identical:
      #   Artist.arid_cache_key(14, :the_key) == Artist.find(14).arid_cache_key(:the_key)
      #
      # When calling in this way, the :auto_expire option is ignored, because you need
      # the record instance to get the value of updated_at.
      #
      # == Example
      #   User.arid_cache_key(1, 'companies') => 'arid-cache-users/1-companies'
      def arid_cache_key(*args)
        options = args.last.is_a?(Hash) ? args.pop : {} # args.extract_options! is not removing the options from the array
        key_base =
          if self.is_a?(Class)
            id, key = args.size == 2 ? args : [nil, args.first]
            if id.present?
              AridCache.class_name(self, :downcase, :pluralize) + '/' + id.to_s + '-' + key.to_s
            else
              AridCache.class_name(self, :downcase) + '-' + key.to_s
            end
          elsif options[:auto_expire]
            self.cache_key + '-' + args.first.to_s
          else
            id, key = (self.respond_to?(:[]) ? self[:id] : nil), args.first
            AridCache.class_name(self, :downcase, :pluralize) + (id.present? ? '/' + id.to_s : '') + '-' + key.to_s
          end
        'arid-cache-' + key_base
      end

      def respond_to?(method, include_private = false) #:nodoc:
        if (method.to_s =~ /^cached_.*(_count)?$/).nil?
          super(method, include_private)
        elsif method.to_s =~ /^cached_(.*)_count$/
          AridCache.store.has?(self, "#{$1}_count") || AridCache.store.has?(self, $1) || super("#{$1}_count", include_private) || super($1, include_private)
        elsif method.to_s =~ /^cached_(.*)$/
          AridCache.store.has?(self, $1) || super($1, include_private)
        else
          super
        end
      end

      protected

      def method_missing(method, *args, &block) #:nodoc:
        if method.to_s =~ /^cached_(.*)$/
          opts = args.empty? ? {} : args.first
          AridCache.lookup(self, $1, opts, &block)
        else
          super
        end
      end
    end

    module ClassMethods

      def instance_caches(opts={}, &block)
        AridCache::Store::InstanceCacheConfiguration.new(self, opts).instance_eval(&block) && nil
      end

      def class_caches(opts={}, &block)
        AridCache::Store::ClassCacheConfiguration.new(self, opts).instance_eval(&block) && nil
      end

      def is_mysql_adapter?
        @is_mysql_adapter ||= !!(::ActiveRecord::Base.connection.adapter_name =~ /MySQL/i)
      end

      def is_mysql_adapter=(value)
        @is_mysql_adapter = value
      end
    end
  end
end
