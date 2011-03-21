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
      # Examples:
      #   User.arid_cache_key('companies')       => 'user-companies'
      #   User.first.arid_cache_key('companies') => 'users/1-companies'
      #   User.first.arid_cache_key('companies', :auto_expire => true) => 'users/20090120091123-companies'
      #
      def arid_cache_key(key, options={})
        object_key = if self.is_a?(Class)
          self.name.downcase
        elsif options[:auto_expire]
          self.cache_key
        else
          "#{self.class.name.downcase.pluralize}/#{self.id}"
        end
        'arid-cache-' + object_key + '-' + key.to_s
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