require 'artd_cache/cache_proxy/options_helpers'
require 'artd_cache/cache_proxy/result'

module AridCache
  class CacheProxy

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
      key = (Utilities.object_class(object)).name.downcase + '-'
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end

    def self.clear_instance_caches(object)
      key = AridCache::Inflector.pluralize((Utilities.object_class(object)).name).downcase
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end

    #
    # Initialize
    #

    def initialize(receiver, method, opts={}, &block)
      @receiver = receiver
      @method = method
      @block = block
      @blueprint = AridCache.store.find(@receiver, @method)

      # Combine the options from the blueprint with the options for this call
      opts = opts.symbolize_keys
      @options = Options.new(@blueprint.nil? ? opts : @blueprint.opts.merge(opts))
      @cache_key = @receiver.arid_cache_key(@method, @options.opts_for_cache_key)
      @cached = Rails.cache.read(@cache_key, @options.opts_for_cache)
    end

    #
    # Fetching results
    #

    # Return a count of ids in the cache, or return whatever is in the cache if it is
    # not a CacheProxy::CachedActiveRecordResult
    def fetch_count
      if @cached.nil? || @options.force?
        execute_count
      elsif @cached.is_a?(CachedActiveRecordResult)
        @cached.has_count? ? @cached.count : execute_count
      elsif @cached.is_a?(Fixnum)
        @cached
      elsif @cached.respond_to?(:count)
        @cached.count
      else
        @cached # what else can we do? return it
      end
    end

    # Return a list of records using the options provided.  If the item in the cache
    # is not a CacheProxy::CachedActiveRecordResult it is returned after applying options.  If there is nothing in the cache
    # the block defining the cache is exectued.  If the :raw option is true, returns the
    # CacheProxy::CachedActiveRecordResult unmodified, ignoring other options, except where those options
    # are needed to initialize the cache.
    def fetch
      if @cached.nil? || @options.force?
        seed_cache
      else
        Result.new(@cached, @options)
      end.process(opts)

      # TODO verify
      elsif @cached.is_a?(CachedActiveRecordResult)
        if @cached.has_ids? && @options.raw?
          @cached                               # return it unmodified
        elsif @cached.has_ids?
          ids = .process(opts)
          fetch_activerecords(ids)              # select only the records we need
        else                                    # true when we have only calculated the count
          seed_cache.process(opts)
        end
      elsif @cached.is_a?(Enumerable)
        Result.new(@cached).process(opts)    # process enumerable in memory
      else
        @cached                                  # base type, return as is
      end
    end

    # Clear the cached result for this cache only
    def clear_cached
      Rails.cache.delete(@cache_key, @options.opts_for_cache)
    end

    private

      include OptionsHelpers

      # Return the class of the cached results i.e. if the cached result is a
      # list of Album records, then klass returns Album.  If there is nothing
      # in the cache, then the class is inferred to be the class of the object
      # that the cached method is being called on.
      def result_klass
        @result_klass ||= if @cached && @cached.is_a?(CachedActiveRecordResult)
          @cached.klass
        else
          Utilities.object_class(@receiver)
        end
      end

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
        if options.paginate?

          # Return a paginated collection
          if cached.ids.empty?

            # No ids, return an empty WillPaginate result
            [].paginate(@options.opts_for_paginate(result_klass))

          elsif combined_options.include?(:order)

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

        elsif combined_options.include?(:order)

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

      # Return a CacheProxy::Result containing the result of calling the proc on the receiver.
      def get_result_from_block
        block = @block || (@blueprint && @blueprint.proc)
        Result.new(block.nil? ? @receiver.instance_eval(@method) : @receiver.instance_eval(&block))
      end

      # Seed the cache by executing the stored block (or by calling a method on the object)
      # and storing the result in the cache.  Return a Result object.
      def seed_cache
        @records = get_result_from_block
        @cached = @records.to_cache
        @cached.klass = Utilities.object_class(@receiver) if @cached.is_a?(CachedActiveRecordResult) && @cached.klass.nil?
        write_cache(@cached)
        @records
      end


      def execute_count
        @result = get_result_from_block
        @cached = CachedActiveRecordResult.new

        # Just get the count if we can.
        #
        # Because of how AssociationProxy works, if we even look at it, it'll
        # trigger the query.  So don't look.
        #
        # Association proxy or named scope.  Check for an association first, because
        # it doesn't trigger the select if it's actually named scope.  Calling respond_to?
        # on an association proxy will hower trigger a select because it loads up the target
        # and passes the respond_to? on to it.
        # TODO FIXME records => @result
        if records.respond_to?(:proxy_reflection) || records.respond_to?(:proxy_options)
          @cached.count = records.count # just get the count
          @cached.klass = Utilities.object_class(@receiver)
        elsif records.is_a?(Enumerable) && (records.empty? || result_is_activerecord?)
          @cached.ids = records.collect(&:id) # get everything now that we have it
          @cached.count = records.size
          @cached.klass = records.empty? ? Utilities.object_class(@receiver) : records.first.class
        else
          @cached = records # some base type, cache it as itself
        end

        write_cache(cached)
        @cached = cached
        cached.respond_to?(:count) ? cached.count : cached
      end

      def write_cache(data)
        Rails.cache.write(@cache_key, data, @options.opts_for_cache)
      end
  end
end