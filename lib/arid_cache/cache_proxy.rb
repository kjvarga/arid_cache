# AridCache::Cache is a singleton instance
module AridCache
  class CacheProxy
    Result = Struct.new(:opts, :ids, :klass, :count) do
      
      def has_count?
        !count.nil?
      end
      
      def has_ids?
        !ids.nil?
      end
    end
    
    # Clear the cache of all arid cache entries.
    #
    # If *object* is passed, only clear cached entries for that object's
    # class and instances e.g.
    #   User.clear_cache deletes 'arid-cache-users/1-companies' as well 
    #   as 'arid-cache-user-companies'
    def clear(object=nil)
      key = 'arid-cache-'
      key += (object.is_a?(Class) ? object : object.class).name.downcase unless object.nil?
      Rails.cache.delete_matched(%r[#{key}.*])
    end
    
    def self.instance
      @@singleton_instance ||= self.new
    end
        
    def has?(object, key)
      Rails.cache.exist?(object.arid_cache_key(key))
    end
    
    def fetch_count(blueprint, opts={})
      cached = Rails.cache.read(blueprint.cache_key)
      if cached.nil? || opts[:force]
        execute_count(blueprint)
      elsif cached.is_a?(AridCache::CacheProxy::Result)
        cached.has_count? ? cached.count : execute_count(blueprint)
      else
        cached # some base type, return it
      end
    end
    
    def fetch(blueprint, opts)
      cached = Rails.cache.read(blueprint.cache_key)
      if cached.nil? || opts[:force]
        execute_find(blueprint, opts)
      elsif cached.is_a?(AridCache::CacheProxy::Result)
        if cached.has_ids? # paginate and fetch here
          klass = opts[:class] || blueprint.opts[:class] || cached.klass 
          if opts.include?(:page)
            klass.paginate(cached.ids, opts_for_paginate(opts, cached))
          else
            klass.find(cached.ids, opts_for_find(opts, cached))
          end
        else
          execute_find(blueprint, opts)
        end
      else
        cached # some base type, return it
      end
    end

    private

      def execute_find(blueprint, opts)
        records = blueprint.proc.call

        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
                
        # Update Rails cache and return the records
        cached = AridCache::CacheProxy::Result.new(blueprint.opts)
        cached.ids = records.collect(&:id)
        cached.count = records.size
        if records.respond_to?(:proxy_reflection) # association proxy
          cached.klass = records.proxy_reflection.klass
        elsif records.is_a?(Enumerable) && !records.empty?
          cached.klass = records.first.class
          Rails.logger.info("** AridCache: inferring class of collection for cache #{blueprint.cache_key} to be #{cached.klass}")
        end
        
        Rails.cache.write(blueprint.cache_key, cached)
        opts.include?(:page) ? records.paginate(opts_for_paginate(opts, cached)) : records      
      end
      
      def execute_count(blueprint)
        records = blueprint.proc.call
        
        # Update Rails cache and return the count
        cached = AridCache::CacheProxy::Result.new(blueprint.opts)

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
          cached.klass = blueprint.klass
        elsif records.is_a?(Enumerable)
          cached.ids = records.collect(&:id) # get everything now that we have it
          cached.count = records.size
          cached.klass = records.empty? ? blueprint.klass : records.first.class
          Rails.logger.info("** AridCache: inferring class of collection for cache #{blueprint.cache_key} to be #{cached.klass}")
        else
          cached = records # some base type, cache it as itself
        end
        
        Rails.cache.write(blueprint.cache_key, cached)
        cached.count
      end
      
      def paginate(records, opts, proc=nil) 
        if !proc.nil?
          ids = opts.include?(:page) ? records.paginate(opts) : records
          records = proc.call(ids)
          ids.is_a?(WillPaginate::Collection) ? ids.replace(records) : records
        else
          opts.include?(:page) ? records.paginate(opts) : records
        end
      end
                  
      def opts_for_paginate(opts, cached)
        opts = cached.opts.merge(opts.symbolize_keys)
        opts[:total_entries] = cached.count
        opts
      end
    
      def opts_for_find(opts, cached)
        opts = cached.opts.merge(opts.symbolize_keys)
        opts.values_at([:include, :joins, :conditions, :order, :group, :having]).compact
      end
    
      def initialize
      end
  end
end