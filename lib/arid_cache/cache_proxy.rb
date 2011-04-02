require 'artd_cache/cache_proxy/options_helpers'

module AridCache
  class CacheProxy

    attr_accessor :object, :key, :opts, :blueprint, :cached, :cache_key, :block, :records, :combined_options, :klass

    # AridCache::CacheProxy::CachedActiveRecordResult
    #
    # This struct is stored in the cache and stores information about a
    # collection of ActiveRecords.
    CachedActiveRecordResult = Struct.new(:ids, :klass, :count) do
      def has_count?
        !count.nil?
      end

      def has_ids?
        !ids.nil?
      end

      def klass=(value)
        self['klass'] = value.is_a?(Class) ? value.name : value.class.name
      end

      def klass
        self['klass'].constantize unless self['klass'].nil?
      end
    end

    OPTIONS_FOR_PAGINATE = [:page, :per_page, :total_entries, :finder]
    OPTIONS_FOR_CACHE_PROXY = [:raw, :clear]
    OPTIONS_FOR_FIND = [ :conditions, :include, :joins, :limit, :offset, :order, :select, :readonly, :group, :having, :from, :lock ]
    OPTIONS_FOR_CACHE = [ :expires_in ]
    OPTIONS_FOR_CACHE_KEY = [ :auto_expire ]

    #
    # Managing your caches
    #

    def self.clear_caches
      Rails.cache.delete_matched(%r[arid-cache-.*])
    end

    def self.clear_class_caches(object)
      key = (object.is_a?(Class) ? object : object.class).name.downcase + '-'
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end

    def self.clear_instance_caches(object)
      key = AridCache::Inflector.pluralize((object.is_a?(Class) ? object : object.class).name).downcase
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end

    def initialize(object, key, opts={}, &block)
      self.object = object
      self.key = key
      self.opts = opts.symbolize_keys
      self.blueprint = AridCache.store.find(object, key)
      self.block = block
      self.records = nil

      # The options from the blueprint merged with the options for this call
      self.combined_options = self.blueprint.nil? ? self.opts : self.blueprint.opts.merge(self.opts)
      self.cache_key = object.arid_cache_key(key, opts_for_cache_key)
    end

    #
    # Fetching results
    #

    # Return a count of ids in the cache, or return whatever is in the cache if it is
    # not a CacheProxy::CachedActiveRecordResult
    def fetch_count
      if refresh_cache?
        execute_count
      elsif cached.is_a?(AridCache::CacheProxy::CachedActiveRecordResult)
        cached.has_count? ? cached.count : execute_count
      elsif cached.is_a?(Fixnum)
        cached
      elsif cached.respond_to?(:count)
        cached.count
      else
        cached # what else can we do? return it
      end
    end

    # Return a list of records using the options provided.  If the item in the cache
    # is not a CacheProxy::CachedActiveRecordResult it is returned after applying options.  If there is nothing in the cache
    # the block defining the cache is exectued.  If the :raw option is true, returns the
    # CacheProxy::CachedActiveRecordResult unmodified, ignoring other options, except where those options
    # are needed to initialize the cache.
    def fetch
      @raw_result = opts_for_cache_proxy[:raw] == true

      result = if refresh_cache?
        execute_find(@raw_result)
      elsif cached.is_a?(AridCache::CacheProxy::CachedActiveRecordResult)
        if cached.has_ids? && @raw_result
          self.cached         # return it unmodified
        elsif cached.has_ids?
          ids = process_enumerable(cached.ids)  # limit and paginate the ids array
          fetch_activerecords(ids)              # select only the records we need
        else                                    # true when we have only calculated the count
          execute_find(@raw_result)
        end
      elsif cached.is_a?(Enumerable)
        process_enumerable(cached)              # process enumerable in memory
      else
        cached                                  # base type, return as is
      end
    end

    # Clear the cached result for this cache only
    def clear_cached
      Rails.cache.delete(self.cache_key, opts_for_cache)
    end

    # Return the cached result for this object's key
    def cached
      @cached ||= Rails.cache.read(self.cache_key, opts_for_cache)
    end

    # Return the class of the cached results i.e. if the cached result is a
    # list of Album records, then klass returns Album.  If there is nothing
    # in the cache, then the class is inferred to be the class of the object
    # that the cached method is being called on.
    def klass
      @klass ||= if self.cached && self.cached.is_a?(AridCache::CacheProxy::CachedActiveRecordResult)
        self.cached.klass
      else
        object_base_class
      end
    end

    private

      include AridCache::CacheProxy::OptionsHelpers

      # Return a list of records from the database using the ids from
      # the cached CachedActiveRecordResult.
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
        if paginate?

          # Return a paginated collection
          if cached.ids.empty?

            # No ids, return an empty WillPaginate result
            [].paginate(opts_for_paginate)

          elsif combined_options.include?(:order)

            # An order has been specified.  We have to go to the database
            # and paginate there because the contents of the requested
            # page will be different.
            klass.paginate(cached.ids, { :total_entries => cached.ids.size }.merge(opts_for_find.merge(opts_for_paginate)))

          else

            # Order is unchanged.  We can paginate in memory and only select
            # those ids that we actually need.  This is the most efficient.
            paged_ids = cached.ids.paginate(opts_for_paginate)
            paged_ids.replace(klass.find_all_by_id(paged_ids, opts_for_find(paged_ids)))

          end

        elsif combined_options.include?(:order)

          # An order has been specified, so use it.
          klass.find_all_by_id(cached.ids, opts_for_find)

        else

          # No order has been specified, so we have to maintain
          # the current order.  We do this by passing some extra
          # SQL which orders by the current array ordering.
          offset, limit = combined_options.delete(:offset) || 0, combined_options.delete(:limit) || cached.count
          ids = cached.ids[offset, limit]

          klass.find_all_by_id(ids, opts_for_find(ids))
        end
      end

      def paginate?
        combined_options.include?(:page)
      end

      def refresh_cache?
        cached.nil? || opts[:force]
      end

      # Return the result of calling the proc on this instance
      def get_result_from_block
        block = self.block || (blueprint && blueprint.proc)
        block.nil? ? object.instance_eval(key) : object.instance_eval(&block)
      end

      # Seed the cache by executing the stored block (or by calling a method on the object).
      # Then apply any options like pagination or ordering before returning the result, which
      # is either some base type, or usually, a list of active records.
      #
      # Options:
      #   raw  - if true, return the CacheProxy::CachedActiveRecordResult after seeding the cache, ignoring
      #          other options. Default is false.
      def execute_find(raw_result = false)
        @records = get_result_from_block
        @cached =  new_cache_proxy_result : records
        write_cache
      end

      def process_result(result)
        if raw_result || !result_is_enumerable? || result_is_empty?
           @cached                   # raw, a base type, or empty; return it
        if result_is_activerecord? && opts.include?(:order) && !opts[:order].is_a?(Proc)
          self.klass = @cached.klass # TODO refactor
          ids = process_enumerable(@cached.ids)  # limit and paginate the ids array
          fetch_activerecords(ids)               # select only the records we need
        else
          process_enumerable(records)            # do it all in memory
        end
      end

      # Return a new CacheProxy CachedActiveRecordResult with information gleaned from +records+,
      # which should be a list of ActiveRecords.
      def new_cache_proxy_result(records)
        if result_is_activerecord? || result_is_empty?
        result = AridCache::CacheProxy::CachedActiveRecordResult.new
        result.ids = records.each { |r| r[:id] }
        result.count = records.size
        if records.respond_to?(:proxy_reflection) # association proxy
          result.klass = records.proxy_reflection.klass
        elsif !records.empty?
          result.klass = records.first.class
        else
          result.klass = object_base_class
        end
        result
      end

      # Return a result after processing it to apply limits or pagination.
      # Only Enumerables
      # Options are only applied if the object responds to the appropriate method.
      # So for example pagination will not happen unless the object responds to :paginate.
      #
      # Options:
      #   :order  - order the results in memory if the value is a Proc.  Ordering is done first, before
      #             applying limits or paginating. The proc is passed to Array#sort to do the sorting.
      #   :limit  - limit the array to the specified size
      #   :offset - ignore the first +offset+ items in the array
      #   :page / :per_page - paginate the result.  If :limit is specified, the array is
      #             limited before paginating; similarly if :offset is specified the array is offset
      #             before paginating.  Pagination only happens if the :page option is passed.
      def process_enumerable(records)
        # Convert records to an array before calling paginate.  If we don't do this
        # and the result is a named scope, paginate will trigger an additional query
        # to load the page rather than just using the records we have already fetched.
        records = records.respond_to?(:to_a) ? records.to_a : records

        # Order
        if opts[:order].is_a?(Proc) && records.respond_to?(:sort)
          records = records.sort(&opts[:order])
        end

        # Limit / Offset
        if (opts.include?(:offset) || opts.include?(:limit)) && records.respond_to?(:[])
          records = records[opts[:offset] || 0, opts[:limit] || records.size]
        end

        # Paginate
        if paginate? && records.respond_to?(:paginate)
          records = records.paginate(opts_for_paginate)
        end

        records
      end

      def execute_count
        @result = get_result_from_block
        @cached = AridCache::CacheProxy::CachedActiveRecordResult.new

        # Just get the count if we can.
        #
        # Because of how AssociationProxy works, if we even look at it, it'll
        # trigger the query.  So don't look.
        #
        # Association proxy or named scope.  Check for an association first, because
        # it doesn't trigger the select if it's actually named scope.  Calling respond_to?
        # on an association proxy will hower trigger a select because it loads up the target
        # and passes the respond_to? on to it.
        if records.respond_to?(:proxy_reflection) || records.respond_to?(:proxy_options)
          @cached.count = records.count # just get the count
          @cached.klass = object_base_class
        elsif records.is_a?(Enumerable) && (records.empty? || result_is_activerecord?)
          @cached.ids = records.collect(&:id) # get everything now that we have it
          @cached.count = records.size
          @cached.klass = records.empty? ? object_base_class : records.first.class
        else
          @cached = records # some base type, cache it as itself
        end

        write_cache
        self.cached = cached
        cached.respond_to?(:count) ? cached.count : cached
      end

      def write_cache
        Rails.cache.write(cache_key, cached, opts_for_cache)
      end

      def object_base_class #:nodoc:
        object.is_a?(Class) ? object : object.class
      end
  end
end