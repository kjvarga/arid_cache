module AridCache
  class CacheProxy
    attr_accessor :object, :key, :opts, :blueprint, :cached, :cache_key, :block, :records
    
    # AridCache::CacheProxy::Result
    #
    # This struct is stored in the cache and stores information we need
    # to re-query for results.
    Result = Struct.new(:ids, :klass, :count) do
      
      def has_count?
        !count.nil?
      end
        
      def has_ids?
        !ids.nil?
      end
            
      def klass=(value)
        self['klass'] = value.is_a?(Class) ? value.name : value
      end
      
      def klass
        self['klass'].constantize unless self['klass'].nil?
      end
    end

    def self.clear_all_caches
      Rails.cache.delete_matched(%r[arid-cache-.*])
    end 
    
    def self.clear_class_caches(object)
      key = (object.is_a?(Class) ? object : object.class).name.downcase + '-'
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end 
        
    def self.clear_instance_caches(object)
      key = (object.is_a?(Class) ? object : object.class).name.pluralize.downcase
      Rails.cache.delete_matched(%r[arid-cache-#{key}.*])
    end    
    
    def self.has?(object, key)
      Rails.cache.exist?(object.arid_cache_key(key))
    end

    def self.fetch_count(object, key, opts, &block)
      CacheProxy.new(object, key, opts, &block).fetch_count
    end
          
    def self.fetch(object, key, opts, &block)
      CacheProxy.new(object, key, opts, &block).fetch
    end

    def initialize(object, key, opts, &block)
      self.object = object
      self.key = key
      self.opts = opts || {}
      self.blueprint = AridCache.store.find(object, key)
      self.cache_key = object.arid_cache_key(key)
      self.cached = Rails.cache.read(cache_key)
      self.block = block
      self.records = nil
    end
            
    def fetch_count
      if cached.nil? || opts[:force]
        execute_count
      elsif cached.is_a?(AridCache::CacheProxy::Result)
        cached.has_count? ? cached.count : execute_count
      elsif cached.is_a?(Fixnum)
        cached
      elsif cached.respond_to?(:count)
        cached.count
      else
        cached # what else can we do? return it
      end
    end
          
    def fetch
      if cached.nil? || opts[:force]
        execute_find
      elsif cached.is_a?(AridCache::CacheProxy::Result)
        if cached.has_ids? # paginate and fetch here
          klass = find_class_of_results
          if opts.include?(:page)
            klass.paginate(cached.ids, opts_for_paginate)
          else
            klass.find(cached.ids, opts_for_find)
          end
        else
          execute_find
        end
      else
        cached # some base type, return it
      end
    end
      
    private

      def get_records
        block = block || blueprint.proc
        self.records = block.nil? ? object.instance_eval(key) : object.instance_eval(&block)
      end
      
      def execute_find
        get_records        
        cached = AridCache::CacheProxy::Result.new
        
        if !records.is_a?(Enumerable) || (!records.empty? && !records.first.is_a?(::ActiveRecord::Base))
          cached = records # some base type, cache it as itself
        else
          cached.ids = records.collect(&:id)
          cached.count = records.size
          if records.respond_to?(:proxy_reflection) # association proxy
            cached.klass = records.proxy_reflection.klass
          elsif !records.empty?
            cached.klass = records.first.class
          else
            cached.klass = object_base_class
          end
        end
        Rails.cache.write(cache_key, cached)
        
        self.cached = cached
        return_records(records)
      end

      # Convert records to an array before calling paginate.  If we don't do this
      # and the result is a named scope, paginate will trigger an additional query
      # to load the page rather than just using the records we have already fetched.
      #
      # If we are not paginating and the options include :limit (and optionally :offset)
      # apply the limit and offset to the records before returning them.
      #
      # Otherwise we have an issue where all the records are returned the first time
      # the collection is loaded, but on subsequent calls the options_for_find are
      # included and you get different results.  Note that with options like :order
      # this cannot be helped.  We don't want to modify the query that generates the
      # collection because the idea is to allow getting different perspectives of the
      # cached collection without relying on modifying the collection as a whole.
      #
      # If you do want a specialized, modified, or subset of the collection it's best
      # to define it in a block and have a new cache for it:
      #
      # model.my_special_collection { the_collection(:order => 'new order') }      
      def return_records(records)
        if opts.include?(:page)
          records = records.respond_to?(:to_a) ? records.to_a : records
          records.respond_to?(:paginate) ? records.paginate(opts_for_paginate) : records
        elsif opts.include?(:limit)
          records = records.respond_to?(:to_a) ? records.to_a : records
          offset = opts[:offset] || 0 
          records[offset, opts[:limit]]
        else
          records
        end      
      end
      
      def execute_count
        get_records
        cached = AridCache::CacheProxy::Result.new

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
          cached.count = records.count # just get the count
          cached.klass = object_base_class
        elsif records.is_a?(Enumerable) && (records.empty? || records.first.is_a?(::ActiveRecord::Base))
          cached.ids = records.collect(&:id) # get everything now that we have it
          cached.count = records.size
          cached.klass = records.empty? ? object_base_class : records.first.class
        else
          cached = records # some base type, cache it as itself
        end
        
        Rails.cache.write(cache_key, cached)
        self.cached = cached
        cached.respond_to?(:count) ? cached.count : cached
      end
                  
      def opts_for_paginate
        paginate_opts = blueprint.nil? ? opts.symbolize_keys : blueprint.opts.merge(opts.symbolize_keys)
        paginate_opts[:total_entries] = cached.count
        paginate_opts
      end
    
      VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset, :order, :select, :readonly, :group, :having, :from, :lock ]
      
      def opts_for_find
        find_opts = blueprint.nil? ? opts.symbolize_keys : blueprint.opts.merge(opts.symbolize_keys) 
        find_opts.delete_if { |k,v| !VALID_FIND_OPTIONS.include?(k) }
      end
      
      def object_base_class
        object.is_a?(Class) ? object : object.class
      end
      
      def find_class_of_results
        opts[:class] || (blueprint && blueprint.opts[:class]) || cached.klass || object_base_class
      end
  end
end