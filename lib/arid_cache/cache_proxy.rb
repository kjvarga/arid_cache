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
        self['klass'] = AridCache.class_name(value)
      end

      def klass
        self[:klass].respond_to?(:constantize) ? self['klass'].constantize : self['klass']
      end
    end

    OPTIONS_FOR_PAGINATE = [:page, :per_page, :total_entries, :finder]
    OPTIONS_FOR_CACHE_PROXY = [:raw, :clear]
    OPTIONS_FOR_FIND = [ :conditions, :where, :include, :includes, :joins, :limit, :offset, :order, :select, :readonly, :group, :having, :from, :lock ]
    OPTIONS_FOR_CACHE = [ :expires_in ]
    OPTIONS_FOR_CACHE_KEY = [ :auto_expire ]

    #
    # Managing your caches
    #

    def self.clear_caches
      Rails.cache.delete_matched(%r[arid-cache-.*])
    end

    def self.clear_class_caches(object)
      key = AridCache.class_name(object, :downcase) + '-'
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end

    def self.clear_instance_caches(object)
      key = AridCache.class_name(object, :downcase, :pluralize)
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
      @options[:receiver_klass] = receiver.is_a?(Class) ? receiver : receiver.class
      @cache_key = @receiver.arid_cache_key(@method, @options.opts_for_cache_key)
      if @options[:pass_options] && block_given?
        raise ArgumentError.new("You must define a method on your object when :pass_options is true.  Blocks cannot be evaluated in context and with arguments, so we cannot use them.")
      end
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
        seed_cache? ? seed_cache : ResultProcessor.new(cached, @options)
      end

      # Return a boolean indicating whether we need to seed the cache.  Seed the cache
      # if :force => true, the cache is empty or records have been requested and there
      # are none in the cache yet.
      def seed_cache?
        cached.nil? || @options.force? || (cached.is_a?(CachedResult) && !@options.count_only? && !cached.has_ids? && cached.klass != NilClass)
      end

      # Seed the cache by executing the stored block (or by calling a method on the object)
      # and storing the result in the cache.  Return the processed result ready to return
      # to the user.
      def seed_cache
        block = @block || (@blueprint && @blueprint.proc)
        block_result = if @options[:pass_options]
            @receiver.send(@method, @options)
          else
            block.nil? ? @receiver.instance_eval(@method) : @receiver.instance_eval(&block)
          end
        @result = ResultProcessor.new(block_result, @options)
        write_cache(@result.to_cache)
        @result
      end

      # Write +data+ to the cache
      def write_cache(data)
        Rails.cache.write(@cache_key, data, @options.opts_for_cache)
      end

      # Return the contents of the cache.  Read from the cache if we have not yet done so.
      def cached
        unless @cached_initialized
          @cached = Rails.cache.read(@cache_key, @options.opts_for_cache)
          @cached_initialized = true # so we don't read multiple times when the value is nil
        end
        @cached
      end
  end
end
