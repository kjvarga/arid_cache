require 'arid_cache/cache_proxy/utilities'

module AridCache
  module CacheProxy
    # A class representing a hash of options with methods to return subsets of
    # those options.
    class Options < Hash
      def initialize(opts={})
        self.merge!(opts)
      end
      
      # Filter options for paginate, if *klass* is set, we get the :per_page value from it.
      def opts_for_paginate(klass=nil)
        paginate_opts = reject { |k,v| !OPTIONS_FOR_PAGINATE.include?(k) }
        paginate_opts[:finder] = :find_all_by_id unless paginate_opts.include?(:finder)
        paginate_opts[:per_page] = klass.per_page if klass && !paginate_opts.include?(:per_page)
        paginate_opts
      end

      # Return options suitable to pass to ActiveRecord::Base#find.
      # Preserve the original order of the results if no :order option is specified.
      #
      # @arg ids array of ids to order by unless an :order option is specified.
      def opts_for_find(ids)
        find_opts = reject { |k,v| !OPTIONS_FOR_FIND.include?(k) }
        find_opts[:order] = AridCache::CacheProxy::Utilities.preserve_order(ids) unless find_opts.include?(:order)
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
    end
  end
end