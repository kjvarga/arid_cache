module AridCache
  class CacheProxy
    # A class representing a hash of options with methods to return subsets of
    # those options.
    class Options < Hash
      def initialize(opts={})
        self.merge!(opts)
      end
      
      # Filter options for paginate.  Get the :per_page value from the receiver if it's not set.
      def opts_for_paginate
        paginate_opts = reject { |k,v| !OPTIONS_FOR_PAGINATE.include?(k) }
        paginate_opts[:finder] = :find_all_by_id unless paginate_opts.include?(:finder)
        paginate_opts[:per_page] = self[:result_klass].per_page if self[:result_klass] && !paginate_opts.include?(:per_page) && self[:result_klass].respond_to?(:per_page)
        paginate_opts
      end

      # Return options suitable to pass to ActiveRecord::Base#find.
      # Preserve the original order of the results if no :order option is specified.
      #
      # @arg ids array of ids to order by unless an :order option is specified.
      def opts_for_find(ids)
        find_opts = reject { |k,v| !OPTIONS_FOR_FIND.include?(k) }
        find_opts[:order] = AridCache::CacheProxy::Utilities.order_by(ids, self[:result_klass]) unless find_opts.include?(:order)
        find_opts
      end

      def opts_for_cache
        reject { |k,v| !OPTIONS_FOR_CACHE.include?(k) }
      end

      def opts_for_cache_key
        reject { |k,v| !OPTIONS_FOR_CACHE_KEY.include?(k) }
      end

      # Returns options that affect the cache proxy result
      def opts_for_cache_proxy
        reject { |k,v| !OPTIONS_FOR_CACHE_PROXY.include?(k) }
      end  
      
      def force?
        !!self[:force]
      end 
      
      def paginate?
        include?(:page)
      end
      
      def raw?
        !!self[:raw]
      end
      
      def count_only?
        !!self[:count_only]
      end
    
      def order_by_proc?
        include?(:order) && self[:order].is_a?(Proc)
      end
      
      def order_by_key?
        include?(:order) && (self[:order].is_a?(Symbol) || self[:order].is_a?(String))
      end
    end
  end
end