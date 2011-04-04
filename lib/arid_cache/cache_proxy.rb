require 'arid_cache/cache_proxy/utilities'
require 'arid_cache/cache_proxy/options'
require 'arid_cache/cache_proxy/result_processor'

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

    # Clear the cached result for this cache only
    def clear_cached
      Rails.cache.delete(@cache_key, @options.opts_for_cache)
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
      result_processor.to_result
    end

    # Return a list of records using the options provided.  If the item in the cache
    # is not a CacheProxy::CachedResult it is returned after applying options.  If there is nothing in the cache
    # the block defining the cache is exectued.  If the :raw option is true, returns the
    # CacheProxy::CachedResult unmodified, ignoring other options, except where those options
    # are needed to initialize the cache.
    def fetch
      result_processor.to_result
    end

    private

      # Return a ResultProcessor instance.  Seed the cache if we need to, otherwise
      # use what is in the cache.
      def result_processor
        seed_cache? ? seed_cache : ResultProcessor.new(@cached, @options)
      end

      # Return a boolean indicating whether we need to seed the cache.  Seed the cache
      # if :force => true, the cache is empty or we need to calculate a count and we haven't yet.
      def seed_cache?
        @cached.nil? || @options.force? || (@cached.is_a?(CachedResult) && @options.count_only? && !@cached.has_count?)
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