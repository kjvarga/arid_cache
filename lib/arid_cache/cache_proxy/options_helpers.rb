module AridCache
  module CacheProxy
    module OptionsHelpers
      # Filter options for paginate, if *klass* is set, we get the :per_page value from it.
      def opts_for_paginate
        paginate_opts = combined_options.reject { |k,v| !OPTIONS_FOR_PAGINATE.include?(k) }
        paginate_opts[:finder] = :find_all_by_id unless paginate_opts.include?(:finder)
        paginate_opts[:per_page] = klass.per_page if klass && !paginate_opts.include?(:per_page)
        paginate_opts
      end

      # Preserve the original order of the results if no :order option is specified.
      #
      # @arg ids array of ids to order by unless an :order option is specified.  If not
      #      specified, cached.ids is used.
      def opts_for_find(ids=nil)
        ids ||= cached.ids
        find_opts = combined_options.reject { |k,v| !OPTIONS_FOR_FIND.include?(k) }
        find_opts[:order] = preserve_order(ids) unless find_opts.include?(:order)
        find_opts
      end

      def opts_for_cache
        combined_options.reject { |k,v| !OPTIONS_FOR_CACHE.include?(k) }
      end

      def opts_for_cache_key
        combined_options.reject { |k,v| !OPTIONS_FOR_CACHE_KEY.include?(k) }
      end

      # Returns options that affect the cache proxy result
      def opts_for_cache_proxy
        combined_options.reject { |k,v| !OPTIONS_FOR_CACHE_PROXY.include?(k) }
      end    
      
      # Generate an ORDER BY clause that preserves the ordering of the ids in *ids*.
      #
      # The method we use depends on the database adapter because only MySQL
      # supports the ORDER BY FIELD() function.  For other databases we use
      # a CASE statement.
      #
      # TODO: is it quicker to sort in memory?
      def preserve_order(ids)
        column = if self.klass.respond_to?(:table_name)
          ::ActiveRecord::Base.connection.quote_table_name(self.klass.table_name) + '.id'
        else
          "id"
        end

        if ids.empty?
          nil
        elsif ::ActiveRecord::Base.is_mysql_adapter?
          "FIELD(#{column},#{ids.join(',')})"
        else
          order = ''
          ids.each_index { |i| order << "WHEN #{column}=#{ids[i]} THEN #{i+1} " }
          "CASE " + order + " END"
        end
      end
    end
  end
end