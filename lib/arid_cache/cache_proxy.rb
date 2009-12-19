# AridCache::Cache is a singleton instance
module AridCache
  class CacheProxy
    Struct.new('Result', :ids, :klass, :count, :opts) do
      def has_count?
        !count.nil?
      end
      
      def has_ids?
        !ids.nil?
      end
    end
    
    def self.instance
      @@singleton_instance ||= self.new
    end
        
    def has?(object, key)
      Rails.cache.exist?(object.arid_cache_key(key))
    end
    
    def fetch_count(blueprint)
      cached = Rails.cache.read(blueprint.cache_key)
      if !cached.is_a?(Struct::Result)
        cached # some base type, return it
      elsif cached.has_count?
        cached.count # we have the count cached
      else
        execute_count(blueprint, cached)
      end
    end
    
    def fetch(blueprint, opts)
      cached = Rails.cache.read(blueprint.cache_key)
      if !cached.is_a?(Struct::Result)
        cached # some base type, return it
      elsif cached.has_ids?
        if opts.include?(:page)
          blueprint.klass.paginate(cached.ids, opts_for_paginate(opts, cached))
        else
          blueprint.klass.find(cached.ids, opts_for_find)
        end
      else
        execute_find(blueprint, cached, opts)
      end
    end

    private

      def execute_find(blueprint, cached, opts)
        records = blueprint.proc.call

        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
                
        # Update Rails cache and return the records
        cached.ids = records.collect(&:id)
        cached.count = records.count
        if records.respond_to?(:proxy_reflection) # association proxy
          cached.klass = records.proxy_reflection.klass
        elsif records.is_a?(Enumerable)
          cached.klass = records.empty? ? blueprint.klass : records.first.class
          RAILS_DEFAULT_LOGGER.info("** AridCache: inferring class of collection for cache #{blueprint.cache_key} to be #{cached.klass}")
        end
        
        Rails.cache.write(blueprint.cache_key, cached)
        opts.include?(:page) ? paginate(records) : records      
      end
      
      def execute_count(blueprint, cached)
        records = blueprint.proc.call
        
        if !records.is_a?(Enumerable)
          return records # some base type, return it
        end
        
        # Update Rails cache and return the count
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
        opts = opts.symbolize_keys
        opts[:total_entries] = cached.count
      end
    
      def opts_for_find(opts)
        opts = opts.symbolize_keys
        opts.values_at([:include, :joins, :conditions, :order, :group, :having]).compact
      end
    
      def initialize
      end
  end
end