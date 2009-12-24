module AridCache
  class CacheProxy
    attr_accessor :object, :key, :opts, :blueprint, :cached, :cache_key, :block
    
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
    
    # Clear the cache of all arid cache entries.
    #
    # If *object* is passed, only clear cached entries for that object's
    # class and instances e.g.
    #   User.clear_cache deletes 'arid-cache-users/1-companies' as well 
    #   as 'arid-cache-user-companies'
    def self.clear(object=nil)
      key = 'arid-cache-'
      key += (object.is_a?(Class) ? object : object.class).name.downcase unless object.nil?
      Rails.cache.delete_matched(%r[#{key}.*])
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
      self.cached = nil
      self.block = block
    end
            
    def fetch_count
      cached = Rails.cache.read(cache_key)
      if cached.nil? || opts[:force]
        execute_count
      elsif cached.is_a?(AridCache::CacheProxy::Result)
        cached.has_count? ? cached.count : execute_count
      else
        cached # some base type, return it
      end
    end

          
    def fetch
      cached = Rails.cache.read(cache_key)
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

      def execute_find
        records = block.nil? ? object.instance_eval(key) : object.instance_eval(&block)

        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
                
        # Update Rails cache and return the records
        self.cached = AridCache::CacheProxy::Result.new
        self.cached.ids = records.collect(&:id)
        self.cached.count = records.size
        if records.respond_to?(:proxy_reflection) # association proxy
          self.cached.klass = records.proxy_reflection.klass
        elsif records.is_a?(Enumerable) && !records.empty?
          self.cached.klass = records.first.class
        end
        
        # Convert records to an array before calling paginate.  If we don't do this
        # and the result is a named scope, paginate will trigger an additional query
        # to load the page rather than just using the records we have already fetched.
        Rails.cache.write(cache_key, self.cached)
        opts.include?(:page) ? records.to_a.paginate(opts_for_paginate) : records      
      end
      
      def execute_count
        records = block.nil? ? object.instance_eval(key) : object.instance_eval(&block)
        
        # Update Rails cache and return the count
        self.cached = AridCache::CacheProxy::Result.new

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
          self.cached.count = records.count # just get the count
          self.cached.klass = object_base_class
        elsif records.is_a?(Enumerable)
          self.cached.ids = records.collect(&:id) # get everything now that we have it
          self.cached.count = records.size
          self.cached.klass = records.empty? ? object_base_class : records.first.class
        else
          self.cached = records # some base type, cache it as itself
        end
        
        Rails.cache.write(cache_key, self.cached)
        self.cached.count
      end
                  
      def opts_for_paginate
        paginate_opts = blueprint.nil? ? opts.symbolize_keys : blueprint.opts.merge(opts.symbolize_keys)
        paginate_opts[:total_entries] = cached.count
        paginate_opts
      end
    
      def opts_for_find
        find_opts = blueprint.nil? ? opts.symbolize_keys : blueprint.opts.merge(opts.symbolize_keys)
        find_opts.values_at([:include, :joins, :conditions, :order, :group, :having]).compact
      end
      
      def object_base_class
        object.is_a?(Class) ? object : object.class
      end
      
      def find_class_of_results
        opts[:class] || (blueprint && blueprint.opts[:class]) || cached.klass 
      end
  end
end