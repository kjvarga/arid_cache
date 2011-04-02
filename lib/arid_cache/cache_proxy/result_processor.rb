module AridCache
  module CacheProxy
    # A class representing a result that is to be processed in some way before
    # being returned to the user.
    #
    # Provides methods to introspect the result.  The contents could be a base type,
    # or an enumerable of sorts...any type really.  We are only concerned with enumerables,
    # and especially those containing active records.
    class ResultProcessor

      def initialize(result, options=nil)
        @result = result
        @options = options
      end

      def
      # Return true if the result is an enumerable and it is empty.
      def is_empty?
        is_enumerable? && @result.empty?
      end

      # Return true if the result is an enumerable.
      def is_enumerable?
        @result.is_a?(Enumerable)
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
      def to_cache(opts={})
        opts.reverse_merge!(:count_only => false)
        if opts[:count_only]
          # Just get the count if we can.
          #
          # Because of how AssociationProxy works, if we even look at it, it'll
          # trigger the query.  So don't look.
          #
          # Association proxy or named scope.  Check for an association first, because
          # it doesn't trigger the select if it's actually named scope.  Calling respond_to?
          # on an association proxy will hower trigger a select because it loads up the target
          # and passes the respond_to? on to it.
          if is_proxy_reflection?
            lazy_cache.count = @result.count # just get the count
            lazy_cache
          elsif is_activerecord? || is_empty?
            lazy_cache.ids = @result.each { |r| r[:id] }
            lazy_cache.count = @result.size
            lazy_cache.klass = @result.first.class unless is_empty?
            lazy_cache
          else
            @result
          end
        else
          if is_activerecord? || is_empty?
            lazy_cache.ids = @result.each { |r| r[:id] }
            lazy_cache.count = @result.size
            if is_proxy_reflection?
              lazy_cache.klass = @result.proxy_reflection.klass
            elsif !is_empty?
              lazy_cache.klass = @result.first.class
            end
            lazy_cache
          else
            @result
          end
        end
      end

      # Apply any options like pagination or ordering and return the result, which
      # is either some base type, or usually, a list of active records.
      def process
        return get_count if @options.count_only?

        # raw, not enumerable, or empty, return it as is
        return @result if @options.raw? || !is_enumerable? || is_empty?

        process_enumerable(@cached.ids)
        if is_activerecord? && @options.include?(:order) && !@options[:order].is_a?(Proc)
          self.klass = @cached.klass # TODO refactor
          ids = process_enumerable(@cached.ids)  # limit and paginate the ids array
          fetch_activerecords(ids)               # select only the records we need
        else

        end
      end

      private

      def get_count
        if @result.is_a?(CachedResult)
          @result.count
        elsif @result.respond_to?(:count)
          @result.count
        else
          @result
        end
      end
      
      # Lazy-initialize a new cached result.  Default the klass of the result to
      # that of the receiver.
      def lazy_cache
        return @lazy_cache if @lazy_cache
        @lazy_cache = AridCache::CacheProxy::CachedResult.new
        @lazy_cache.klass = Utilities.object_class(@options[:receiver])
        @lazy_cache
      end

      # Return the result after processing it to apply limits or pagination.
      #
      # Options are only applied if the object responds to the appropriate method.
      # So for example pagination will not happen unless the object responds to :paginate.
      #
      # Options:
      #   :order  - ignored unless it is a Proc.  Ordering is done first, before
      #             applying limits or paginating. The proc is passed to Array#sort to do the sorting.
      #   :limit  - limit the array to the specified size
      #   :offset - ignore the first +offset+ items in the array
      #   :page / :per_page - paginate the result.  If :limit is specified, the array is
      #             limited before paginating; similarly if :offset is specified the array is offset
      #             before paginating.  Pagination only happens if the :page option is passed.
      def process_enumerable

        # Order
        if @options[:order].is_a?(Proc) && records.respond_to?(:sort)
          records = records.sort(&@options[:order])
        end

        # Limit / Offset
        if (@options.include?(:offset) || @options.include?(:limit)) && records.respond_to?(:[])
          records = records[@options[:offset] || 0, @options[:limit] || records.size]
        end

        # Paginate
        if paginate? && records.respond_to?(:paginate)
          # Convert records to an array before calling paginate.  If we don't do this
          # and the result is a named scope, paginate will trigger an additional query
          # to load the page rather than just using the records we have already fetched.
          records = records.respond_to?(:to_a) ? records.to_a : records
          records = records.paginate(@options.opts_for_paginate)
        end

        records
      end
      
      # Return a list of records from the database using the ids from
      # the cached CachedResult.
      #
      # The result is paginated if the :page option is preset, otherwise
      # a regular list of ActiveRecord results is returned.
      #
      # If no :order is specified, the current ordering of the ids is
      # preserved with some fancy SQL.
      #
      # Call only when the list of records is not empty and an order option
      # has been specified and it is not a Proc.
      def fetch_activerecords
        if @options.paginate?

          # Return a paginated collection
          if cached.ids.empty?

            # No ids, return an empty WillPaginate result
            [].paginate(@@options.opts_for_paginate(result_klass))

          elsif @options.include?(:order)

            # An order has been specified.  We have to go to the database
            # and paginate there because the contents of the requested
            # page will be different.
            result_klass.paginate(cached.ids, { :total_entries => cached.ids.size }.merge(@options.opts_for_find(cached.ids).merge(@options.opts_for_paginate(result_klass))))

          else

            # Order is unchanged.  We can paginate in memory and only select
            # those ids that we actually need.  This is the most efficient.
            paged_ids = cached.ids.paginate(@options.opts_for_paginate(result_klass))
            paged_ids.replace(result_klass.find_all_by_id(paged_ids, @options.opts_for_find(paged_ids)))

          end

        elsif @options.include?(:order)

          # An order has been specified, so use it.
          result_klass.find_all_by_id(cached.ids, @options.opts_for_find(cached.ids))

        else

          # No order has been specified, so we have to maintain
          # the current order.  We do this by passing some extra
          # SQL which orders by the current array ordering.
          # Delete the offset and limit so they aren't applied in find.
          find_opts = @options.opts_for_find(ids)
          offset, limit = find_opts.delete(:offset) || 0, find_opts.delete(:limit) || cached.count
          ids = cached.ids[offset, limit]
          result_klass.find_all_by_id(ids, find_opts)
        end
      end
    end
  end
end