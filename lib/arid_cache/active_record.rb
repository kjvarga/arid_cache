module AridCache
  module ActiveRecord
    module MirrorMethods
      
      # Return a cache key for the given key e.g.
      #   User.arid_cache_key('companies')       => 'user-companies'
      #   User.first.arid_cache_key('companies') => 'users/1-companies'
      def arid_cache_key(key, suffix=nil)
        arid_cache_key = (self.is_a?(Class) ? self.name.downcase : self.cache_key) + '-' + key.to_s
        suffix.nil? ? arid_cache_key : arid_cache_key + suffix
        ('arid-cache-' + arid_cache_key).to_sym
      end

      def clear_cache
        AridCache.cache.clear(self)
      end
          
      # Return the cache store from the class
      def cache_store
        (self.is_a?(Class) ? self : self.class).send(:class_variable_get, :@@cache_store)
      end    

      # Intercept methods beginning with <tt>cached_</tt>
      def method_missing_with_arid_cache(method, *args, &block)
        if method.to_s =~ /^cached_(.*)$/
          args = args.empty? ? {} : args.first
          cache_store.query($1, args, self, &block)
        else
          method_missing_without_arid_cache(method, *args)
        end
      end 
      alias_method :method_missing_without_arid_cache, :method_missing
      alias_method :method_missing, :method_missing_with_arid_cache
    end
          
    def self.included(base)
      base.extend         MirrorMethods
      base.send :include, MirrorMethods
      base.class_eval do
        @@cache_store = AridCache::Store.new
      end
    end
  end
end
