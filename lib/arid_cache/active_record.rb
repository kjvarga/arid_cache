module AridCache
  module ActiveRecord
    module MirrorMethods
      
      # Return a cache key for the given key e.g.
      #   User.arid_cache_key('companies')       => 'user-companies'
      #   User.first.arid_cache_key('companies') => 'users/1-companies'
      def arid_cache_key(key, suffix=nil)
        return @arid_cache_key if instance_variable_defined?(:@arid_cache_key)
        arid_cache_key = (self.is_a?(Class) ? self.name.downcase : self.cache_key) + '-' + key.to_s
        suffix.nil? ? arid_cache_key : arid_cache_key + suffix
        @arid_cache_key = arid_cache_key.to_sym
      end
    
      # Return the cache store from the class
      def cache_store
        (self.is_a?(Class) ? self : self.class).send(:class_variable_get, :@@cache_store)
      end    

      # Intercept methods beginning with <tt>cached_</tt>
      def method_missing_with_arid_cache(method, *args, &block)
        if method.to_s =~ /^cached_(.*)$/
          cache_store.query($1, args, self, &block)
        else
          method_missing_without_arid_cache(method, *args)
        end
      end 
    end
          
    def self.included(base)
      base.extend         MirrorMethods
      base.send :include, MirrorMethods
      base.class_eval do
        @@cache_store = AridCache::Store.new
        alias_method_chain :method_missing, :arid_cache
      end
    end
  end
end
