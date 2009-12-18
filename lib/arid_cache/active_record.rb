module AridCache
  module ActiveRecord
    module MirrorMethods
      def cache_store
        (self.is_a?(Class) ? self : self.class).send(:class_variable_get, :@@cache_store)
      end    

      # Replace method missing
      alias_method :replaced_method_missing, :method_missing
      def method_missing(method, *args, &block)
        if method.to_s =~ /^cached_(.*)$/
          cache_store.query($1, args, self, &block)
        else
          replaced_method_missing(method, *args)
        end
      end 
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
