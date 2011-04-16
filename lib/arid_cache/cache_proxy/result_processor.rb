module AridCache
  class CacheProxy
    # A class representing a result that is to be processed in some way before
    # being returned to the user.
    #
    # Provides methods to introspect the result.  The contents could be a base type,
    # or an enumerable of sorts...any type really.  We are only concerned with enumerables,
    # and especially those containing active records.
    #
    # TODO: a lot of this logic should be encompassed in the CachedResult.  It's probably
    # a good idea to always cache a CachedResult and move the result-related methods
    # into that class.  We have to keep whatever is cached as small as possible tho,
    # so it's probably best to cache a Hash and load it with CachedResult.
    class ResultProcessor

      def initialize(result, opts={})
        @result = result
        @options = opts.is_a?(AridCache::CacheProxy::Options) ? opts : AridCache::CacheProxy::Options.new(opts)
      end

      # Return true if the result is an array and it is empty.
      def is_empty?
        @result.is_a?(Array) && @result.empty?
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
        (is_cached_result? && !@options.raw?) || (@options.order_by_key? && is_activerecord?)
      end

      # Return true if the result is an enumerable and the first item is
      # an active record.
      def is_activerecord?
        AridCache.framework.active_record? && is_enumerable? && @result.first.is_a?(::ActiveRecord::Base)
      end

      def is_activerecord_reflection?
        AridCache.framework.active_record? && (@result.respond_to?(:proxy_reflection) || @result.respond_to?(:proxy_options) || (AridCache.framework.active_record?(3) && @result.is_a?(::ActiveRecord::Relation)))
      end

      def is_cached_result?
        @result.is_a?(AridCache::CacheProxy::CachedResult)
      end

      # Return the result to cache.  For base types the original result is
      # returned.  ActiveRecords return a CachedResult.
      def to_cache
        # Check if it's an association first, because it doesn't trigger the select if it's
        # a named scope.  Calling respond_to? on an association proxy will trigger a select
        # because it loads up the target and passes the respond_to? on to it.
        @cached =
          if @options.proxy?
            if is_activerecord_reflection?
              @result = @result.collect { |r| r } # force it to load
            end
            Utilities.object_class(@options[:receiver]).send(@options[:proxy], @result)
          elsif is_activerecord_reflection?

            if @options.count_only?
              lazy_cache.count = @result.count
            else
              lazy_cache.ids = @result.collect { |r| r[:id] }
              lazy_cache.klass = @result.respond_to?(:proxy_reflection) ? @result.proxy_reflection.klass : (is_empty? ? result_klass : @result.first.class)
              lazy_cache.count = @result.size
            end
            lazy_cache
          elsif is_activerecord?
            lazy_cache.ids = @result.collect { |r| r[:id] }
            lazy_cache.count = @result.size
            lazy_cache.klass = @result.first.class
            lazy_cache
          elsif is_empty? && !AridCache.raw_with_options # deprecated behaviour
            lazy_cache.ids = @result
            lazy_cache.count = 0
            lazy_cache.klass = result_klass
            lazy_cache
          elsif @result.nil? # so we can distinguish a cached nil vs an empty cache
            lazy_cache.klass = NilClass
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

        elsif @options.proxy?
          results =
            if @cached.nil? || !@options.raw?
              @result
            else
              @cached
            end
          filtered = filter_results(results)
          if @cached.nil? && !@options.raw?
            proxy_result = Utilities.object_class(@options[:receiver]).send(@options[:proxy], filtered)
            if filtered.is_a?(WillPaginate::Collection) && proxy_result.is_a?(Enumerable)
              filtered.replace(proxy_result)
            else
              proxy_result
            end
          else
            filtered
          end

        elsif (@cached || @result).is_a?(AridCache::CacheProxy::CachedResult) && (@cached || @result).klass == NilClass
          nil

        elsif @options.raw?
          result =
            if @cached.is_a?(AridCache::CacheProxy::CachedResult)
              @cached
            else
              @result
            end
          if @options.deprecated_raw?
            result
          else
            filter_results(result.is_a?(AridCache::CacheProxy::CachedResult) ? result.ids : result)
          end

        elsif is_cached_result?
          fetch_activerecords(filter_results(@result.ids))
        elsif order_in_database?
          fetch_activerecords(filter_results(@result))
        else
          filter_results(@result)
        end
      end

      private

      def get_count
        if @cached.is_a?(AridCache::CacheProxy::CachedResult) # use what we put in the cache
          @cached.count
        elsif @result.respond_to?(:count)
          @result.count
        else
          @result
        end
      end

      # Lazy-initialize a new cached result.
      def lazy_cache
        @lazy_cache ||= AridCache::CacheProxy::CachedResult.new
      end

      # Return the result after processing it to apply limits or pagination in memory.
      # Doesn't do anything if we have to order in the databse.
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
          records = records.paginate(@options.opts_for_paginate(records))
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
        if records.empty?
          if @options.paginate?
            return records.paginate(@options.opts_for_paginate(records))
          else
            return records
          end
        end

        ids = AridCache.framework.active_record? && records.first.is_a?(ActiveRecord) ? records.collect { |record| record[:id] } : records
        find_opts = @options.opts_for_find(ids)
        if order_in_database?
          if @options.paginate?
            if AridCache.framework.active_record?(3)
              page_opts = @options.opts_for_paginate(ids)
              WillPaginate::Collection.create(page_opts[:page], page_opts[:per_page], page_opts[:total_entries]) do |pager|
                result = find_all_by_id(ids, find_opts.merge(:limit => pager.per_page, :offset => pager.offset))
                pager.replace(result)
              end
            else
              find_opts.merge!(@options.opts_for_paginate(ids))
              result_klass.paginate(ids, find_opts)
            end
          else
            find_all_by_id(ids, find_opts)
          end
        else
          # Limits will have already been applied, remove them from the options for find.
          [:offset, :limit].each { |key| find_opts.delete(key) }
          result = find_all_by_id(ids, find_opts)
          records.is_a?(::WillPaginate::Collection) ? records.replace(result) : result
        end
      end

      # Return the klass to use for building results (only applies to ActiveRecord results)
      def result_klass
        is_cached_result? ? @result.klass : (@cached.is_a?(AridCache::CacheProxy::CachedResult) ? @cached.klass : Utilities.object_class(@options[:receiver]))
      end

      def find_all_by_id(ids, find_opts)
        if AridCache.framework.active_record?(3)
          option_map = {
            :conditions => :where,
            :include => :includes
          }
          query = find_opts.inject(result_klass.scoped) do |scope, pair|
            key, value = pair
            key = option_map[key] || key
            scope.send(key, pair[1])
          end
          query = query.scoped.where(Utilities.namespaced_column(:id, result_klass) + ' in (?)', ids)
          # Fix http://breakthebit.org/post/3487560245/rails-3-arel-count-size-length-weirdness
          query.class_eval do
            alias_method :size, :length
            alias_method :count, :length
          end
          query
        else
          result_klass.find_all_by_id(ids, find_opts)
        end
      end
    end
  end
end
