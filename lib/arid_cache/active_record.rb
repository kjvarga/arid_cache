module AridCache
  module ActiveRecord      
    def self.included(base)
      base.extend         MirrorMethods
      base.send :include, MirrorMethods
      base.class_eval do
        alias_method_chain :method_missing, :arid_cache 
      end
      class << base
        alias_method_chain :method_missing, :arid_cache 
      end
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
                  
      def get_singleton
        class << self; self; end
      end
      
      # Return an ARID Cache key for the given key fragment for this object.
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
        if (method.to_s =~ /^class_cache_.*|cache_.*|cached_.*(_count)?$/).nil?
          super(method, include_private)
        elsif method.to_s =~ /^cached_(.*)_count$/
          AridCache.store.has?(self, "#{$1}_count") || AridCache.store.has?(self, $1) || super("#{$1}_count", include_private) || super($1, include_private)
        elsif method.to_s =~ /^cached_(.*)$/
          AridCache.store.has?(self, $1) || super($1, include_private)
        else
          super(method, include_private)
        end
      end
            
      protected

      # Intercept methods beginning with <tt>cached_</tt>
      def method_missing_with_arid_cache(method, *args, &block) #:nodoc:
        opts = args.empty? ? {} : args.first
        if method.to_s =~ /^cache_(.*)$/
          AridCache.define(self, $1, opts, &block)
        elsif method.to_s =~ /^cached_(.*)$/
          AridCache.lookup(self, $1, opts, &block)
        else
          method_missing_without_arid_cache(method, *args)
        end
      end
    end
  end
end