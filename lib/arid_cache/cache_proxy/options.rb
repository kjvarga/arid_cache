module AridCache
  class CacheProxy
    # A class representing a hash of options with methods to return subsets of
    # those options.
    class Options < Hash
      def initialize(opts={})
        self.merge!(opts)
      end

      # Filter options for paginate.
      # Set total_entries to +records.size+ if +records+ is supplied
      # Get the :per_page value from the +result_klass+, or +receiver_klass+ if its set
      # and responds to +per_page+.  Otherwise default to 30 results per page.
      def opts_for_paginate(records=nil)
        paginate_opts = reject { |k,v| !OPTIONS_FOR_PAGINATE.include?(k) }
        paginate_opts[:finder] = :find_all_by_id unless paginate_opts.include?(:finder)
        unless paginate_opts.key?(:per_page)
          klass = values_at(:result_klass, :receiver_klass).find do |klass|
            klass.respond_to?(:per_page)
          end
          paginate_opts[:per_page] = klass && klass.per_page || 30
        end
        paginate_opts[:page] = 1 if paginate_opts[:page].nil?
        paginate_opts[:total_entries] = records.size unless records.nil?
        paginate_opts
      end

      # Return options suitable to pass to ActiveRecord::Base#find.
      # Preserve the original order of the results if no :order option is specified.
      # If an offset is specified but no limit, ActiveRecord will not apply the offset,
      # so pass in a limit that is as big as +ids.size+
      #
      # @arg ids array of ids to order by unless an :order option is specified.
      def opts_for_find(ids)
        find_opts = reject { |k,v| !OPTIONS_FOR_FIND.include?(k) }
        if !find_opts.include?(:order) && !AridCache.order_in_memory?
          find_opts[:order] = AridCache.order_by(ids, self[:result_klass])
        elsif order_by_proc?
          find_opts.delete(:order)
        end
        find_opts[:limit] = ids.size unless find_opts.include?(:limit)
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

      # Return true if the user has defined a proxy for results processing in the given
      # direction.
      #
      # * +direction+ - :in or :out, depending on whether we are putting results into
      #                 the cache, or returning results from the cache, respectively
      def proxy?(direction)
        include?(:proxy) || include?("proxy_#{direction}".to_sym)
      end

      def deprecated_raw?
        !!(raw? && !AridCache.raw_with_options)
      end

      # Returns the class of the receiver object or raises IndexError if the
      # receiver klass has not been set.
      def receiver_klass
        fetch :receiver_klass
      end

      # Returns the class of the result records or raises IndexError if the
      # result klass has not been set.
      def result_klass
        fetch :result_klass
      end

      # Return the user's proxy method for the given direction.  Returns a symbol, Proc
      # or nil if no proxy is defined.
      #
      # * +direction+ - :in or :out, depending on whether we are putting results into
      #                 the cache, or returning results from the cache, respectively
      def proxy(direction)
        self[:proxy] || self["proxy_#{direction}".to_sym]
      end
    end
  end
end
