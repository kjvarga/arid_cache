require 'artd_cache/cache_proxy/options'
require 'artd_cache/cache_proxy/result'

module AridCache
  class CacheProxy

    # AridCache::CacheProxy::CachedResult
    #
    # This struct is stored in the cache and stores information about a
    # collection of ActiveRecords.
    CachedResult = Struct.new(:ids, :klass, :count) do
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
      @options[:receiver] = receiver
      @cache_key = @receiver.arid_cache_key(@method, @options.opts_for_cache_key)
      @cached = Rails.cache.read(@cache_key, @options.opts_for_cache)
    end

    #
    # Fetching results
    #

    # Return a count of ids in the cache, or return whatever is in the cache if it is
    # not a CacheProxy::CachedResult
    def fetch_count
      @options[:count_only] = true
      new_result.process
      

    end

    # Return a list of records using the options provided.  If the item in the cache
    # is not a CacheProxy::CachedResult it is returned after applying options.  If there is nothing in the cache
    # the block defining the cache is exectued.  If the :raw option is true, returns the
    # CacheProxy::CachedResult unmodified, ignoring other options, except where those options
    # are needed to initialize the cache.
    def fetch
      new_result.process
      
      # TODO verify
      elsif @cached.is_a?(CachedResult)
        if @cached.has_ids? && @options.raw?
          @cached                               # return it unmodified
        elsif @cached.has_ids?
          ids = .process(opts)
          fetch_activerecords(ids)              # select only the records we need
        else                                    # true when we have only calculated the count
          seed_cache
        end
      elsif @cached.is_a?(Enumerable)
        ResultProcessor.new(@cached).process(opts)    # process enumerable in memory
      else
        @cached                                  # base type, return as is
      end
    end

    # Clear the cached result for this cache only
    def clear_cached
      Rails.cache.delete(@cache_key, @options.opts_for_cache)
    end

    private

      # Return a ResultProcessor instance.  Seed the cache if we need to, otherwise
      # use what's in the cache.
      def new_result
        seed_cache? ? seed_cache : ResultProcessor.new(@cached, @options)
      end

      # Return a boolean indicating whether we need to seed the cache
      def seed_cache?
        @cached.nil? || @options.force? || (@cached.is_a?(CachedResult) && @options.count_only? && !@cached.has_count?)
      end
      
      # Return the class of the cached results i.e. if the cached result is a
      # list of Album records, then klass returns Album.  If there is nothing
      # in the cache, then the class is inferred to be the class of the object
      # that the cached method is being called on.
      def result_klass
        @result_klass ||= if @cached && @cached.is_a?(CachedResult)
          @cached.klass
        else
          Utilities.object_class(@receiver)
        end
      end

      # Seed the cache by executing the stored block (or by calling a method on the object)
      # and storing the result in the cache.  Return the processed result ready to return
      # to the user.
      def seed_cache
        block = @block || (@blueprint && @blueprint.proc)
        block_result = block.nil? ? @receiver.instance_eval(@method) : @receiver.instance_eval(&block)
        @result = ResultProcessor.new(block_result, @options)
        write_cache(@result.to_cache)
        @result
      end

      def write_cache(data)
        Rails.cache.write(@cache_key, data, @options.opts_for_cache)
      end
  end
end