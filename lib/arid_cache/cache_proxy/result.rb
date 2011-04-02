module AridCache
  module CacheProxy
    # A class representing a result that is to be processed in some way before
    # being returned to the user.
    #
    # Provides methods to introspect the result.  The contents could be a base type,
    # or an enumerable of sorts...any type really.  We are only concerned with enumerables,
    # and especially those containing active records.
    class Result

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

      # Return the result to cache.  For base types the original result is
      # returned.  ActiveRecords return a CachedActiveRecordResult.
      def to_cache
        if is_activerecord? || is_empty?
          cache = AridCache::CacheProxy::CachedActiveRecordResult.new
          cache.ids = @result.each { |r| r[:id] }
          cache.count = @result.size
          if @result.respond_to?(:proxy_reflection) # association proxy
            cache.klass = @result.proxy_reflection.klass
          elsif !@result.empty?
            cache.klass = @result.first.class
          end
          cache
        else
          @result
        end
      end
      
      # Then apply any options like pagination or ordering before returning the result, which
      # is either some base type, or usually, a list of active records.
      #
      # Options:
      #   raw  - if true, return the CacheProxy::CachedActiveRecordResult after seeding the cache, ignoring
      #          other options. Default is false.
      def process(options=nil)
        @options ||= options
        
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
    end
  end
end