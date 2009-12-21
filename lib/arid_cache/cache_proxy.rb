# AridCache::Cache is a singleton instance
module AridCache
  class CacheProxy
    Struct.new('Result', :opts, :ids, :klass, :count) do
      
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
      Rails.cache.delete_matched(%r[#{key}])
    end
    
    def self.instance
      @@singleton_instance ||= self.new
    end
        
    def has?(object, key)
      Rails.cache.exist?(object.arid_cache_key(key))
    end
    
    def fetch_count(blueprint)
      cached = Rails.cache.read(blueprint.cache_key)
      if cached.nil?
        execute_count(blueprint)
      elsif !cached.is_a?(Struct::Result)
        cached # some base type, return it
      elsif cached.has_count?
        cached.count # we have the count cached
      end
    end
    
    def fetch(blueprint, opts)
      cached = Rails.cache.read(blueprint.cache_key)
      if cached.nil? || !cached.has_ids?
        execute_find(blueprint, opts)
      elsif !cached.is_a?(Struct::Result)
        cached # some base type, return it
      elsif cached.has_ids?
        if opts.include?(:page)
          blueprint.klass.paginate(cached.ids, opts_for_paginate(opts, cached))
        else
          blueprint.klass.find(cached.ids, opts_for_find(opts, cached))
        end
      end
    end

    private

      def execute_find(blueprint, opts)
        records = blueprint.proc.call

        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
                
        # Update Rails cache and return the records
        cached = Struct::Result.new(opts.symbolize_keys!)
        cached.ids = records.collect(&:id)
        cached.count = records.count
        if records.respond_to?(:proxy_reflection) # association proxy
          cached.klass = records.proxy_reflection.klass
        elsif records.is_a?(Enumerable)
          cached.klass = records.empty? ? blueprint.klass : records.first.class
          RAILS_DEFAULT_LOGGER.info("** AridCache: inferring class of collection for cache #{blueprint.cache_key} to be #{cached.klass}")
        end
        
        Rails.cache.write(blueprint.cache_key, cached)
        opts.include?(:page) ? records.paginate(opts_for_paginate(opts, cached)) : records      
      end
      
      def execute_count(blueprint)
        records = blueprint.proc.call
        
        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
        
        # Update Rails cache and return the count
        cached = Struct::Result.new
        if records.respond_to?(:proxy_options)
          cached.count = records.count # named scope, just get the count
          cached.klass = blueprint.klass
        elsif records.is_a?(Enumerable)
          cached.ids = records.collect(&:id) # get everything now that we have it
          cached.count = records.count
          cached.klass = records.empty? ? blueprint.klass : records.first.class
          RAILS_DEFAULT_LOGGER.info("** AridCache: inferring class of collection for cache #{blueprint.cache_key} to be #{cached.klass}")
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