module AridCache
  class CacheProxy
    # A class representing a result that is to be processed in some way before
    # being returned to the user.
    #
    # Provides methods to introspect the result.  The contents could be a base type,
    # or an enumerable of sorts...any type really.  We are only concerned with enumerables,
    # and especially those containing active records.
    class ResultProcessor

      def initialize(result, opts={})
        @result = result
        @options = opts.is_a?(AridCache::CacheProxy::Options) ? opts : AridCache::CacheProxy::Options.new(opts)

        @result_klass = @options[:result_klass] = is_cached_result? ? @result.klass : Utilities.object_class(@options[:receiver])
      end

      # Return true if the result is an enumerable and it is empty.
      def is_empty?
        is_enumerable? && @result.empty?
      end

      # Return true if the result is an enumerable.
      def is_enumerable?
        @result.is_a?(Enumerable)
      end

      # Return true if the result is a list of hashes
      def is_hashes?
        is_enumerable? && @result.first.is_a?(Hash)
      end

      # Order in the database if an order clause has been specified and we
      # have a list of ActiveRecords or a CachedResult.
      def order_in_database?
        @options.order_by_key? && (is_activerecord? || is_cached_result?)
      end

      # Return true if the result is an enumerable and the first item is
      # an active record.
      def is_activerecord?
        is_enumerable? && @result.first.is_a?(::ActiveRecord::Base)
      end

      def is_proxy_reflection?
        @result.respond_to?(:proxy_reflection) || @result.respond_to?(:proxy_options)
      end

      def is_cached_result?
        @result.is_a?(AridCache::CacheProxy::CachedResult)
      end

      # Return the result to cache.  For base types the original result is
      # returned.  ActiveRecords return a CachedResult.
      def to_cache
        # Ceck if it's an association first, because it doesn't trigger the select if it's
        # a named scope.  Calling respond_to? on an association proxy will trigger a select
        # because it loads up the target and passes the respond_to? on to it.
        if is_proxy_reflection?
          lazy_cache.klass = @result.proxy_reflection.klass
          unless @options.count_only?
            lazy_cache.ids = @result.collect { |r| r[:id] }
          end
          lazy_cache.count = @result.count
          lazy_cache
        elsif is_activerecord? || is_empty?
          lazy_cache.ids = @result.collect { |r| r[:id] }
          lazy_cache.count = @result.size
          lazy_cache.klass = @result.first.class
          lazy_cache
        else
          @result
        end
      end

      # Apply any options like pagination or ordering and return the result, which
      # is either some base type, or usually, a list of active records.
      def to_result
        if @options.count_only?
          get_count
        elsif @options.raw? || !is_enumerable?
          @result
        else
          if is_cached_result?
            fetch_activerecords(filter_results(@result.ids))
          elsif order_in_database?
            fetch_activerecords(filter_results(@result))
          else
            filter_results(@result)
          end
        end
      end

      private

      def get_count
        @result.respond_to?(:count) ? @result.count : @result
      end

      # Lazy-initialize a new cached result.  Default the klass of the result to
      # that of the receiver.
      def lazy_cache
        return @lazy_cache if @lazy_cache
        @lazy_cache = AridCache::CacheProxy::CachedResult.new
        @lazy_cache.klass = @options[:result_klass]
        @lazy_cache
      end

      # Return the result after processing it to apply limits or pagination in memory.
      # Not to be called when we have to order in the databse.
      #
      # Options are only applied if the object responds to the appropriate method.
      # So for example pagination will not happen unless the object responds to :paginate.
      #
      # Options:
      #   :order  - Ordering is done first, before applying limits or paginating.
      #             If it's a Proc it is passed to Array#sort to do the sorting.
      #             If it is a Symbol or String the results should be Hashes and the
      #             list of Hashes are sorted by the values at the given key.
      #   :limit  - limit the array to the specified size
      #   :offset - ignore the first +offset+ items in the array
      #   :page / :per_page - paginate the result.  If :limit is specified, the array is
      #             limited before paginating; similarly if :offset is specified the array is offset
      #             before paginating.  Pagination only happens if the :page option is passed.
      def filter_results(records)
        return records if order_in_database?

        # Order in memory
        if records.respond_to?(:sort)
          if @options.order_by_proc?
            records = records.sort(&@options[:order])
          elsif @options.order_by_key? && is_hashes?
            records = records.sort do |a, b|
              a[@options[:order]] <=> b[@options[:order]]
            end
          end
        end

        # Limit / Offset
        if (@options.include?(:offset) || @options.include?(:limit)) && records.respond_to?(:[])
          records = records[@options[:offset] || 0, @options[:limit] || records.size]
        end

        # Paginate
        if @options.paginate? && records.respond_to?(:paginate)
          # Convert records to an array before calling paginate.  If we don't do this
          # and the result is a named scope, paginate will trigger an additional query
          # to load the page rather than just using the records we have already fetched.
          records = records.respond_to?(:to_a) ? records.to_a : records
          records = records.paginate(@options.opts_for_paginate, { :total_entries => ids.size })
        end
        records
      end

      # Return a list of records from the database.  +records+ is a list of
      # ActiveRecords or a list of ActiveRecord ids.
      #
      # If no :order is specified, the current order is preserved with some fancy SQL.
      # If an arder is specified then
      # order, limit and paginate in the database.
      def fetch_activerecords(records)
        ids = records.first.is_a?(ActiveRecord) ? records.collect { |record| record[:id] } : records
        find_opts = @options.opts_for_find(ids)
        if order_in_database?
          if @options.paginate?
            find_opts.merge!(@options.opts_for_paginate)
            @result_klass.paginate(ids, { :total_entries => ids.size }.merge(find_opts))
          else
            @result_klass.find_all_by_id(ids, find_opts)
          end
        else
          # Limits will have already been applied, remove them from the options for find.
          [:offset, :limit].each { |key| find_opts.delete(key) }
          result = @result_klass.find_all_by_id(ids, find_opts)
          records.is_a?(WIllPaginate::Collection) ? records.replace(result) : result
        end
      end
    end
  end
end