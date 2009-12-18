require 'arid_cache/helpers'
require 'arid_cache/store'
require 'will_paginate'

module AridCache
  module ClassMethods


    
    # Replace method missing
    # alias_method :replaced_method_missing, :method_missing
    #     def method_missing(method, *args, &block)
    #       if method.to_s =~ /^cached_(.*)$/
    #         AridCache::Helpers.arid_cache($1, *(args << self), &block)
    #       else
    #         replaced_method_missing(method, *args, &block)
    #       end
    #     end
    
  end
  
  module MirrorMethods

    def cache_store
      (self.is_a?(Class) ? self : self.class).send(:class_variable_get, :@@cache_store)
    end    

    
    # Replace method missing
    alias_method :replaced_method_missing, :method_missing
    def method_missing(method, *args, &block)
      if method.to_s =~ /^cached_(.*)$/
        AridCache::Helpers.arid_cache($1, args, self, &block)
      else
        replaced_method_missing(method, *args)
      end
    end 
      
  end
  
  def self.included(receiver)
    receiver.extend         MirrorMethods
    receiver.send :include, MirrorMethods
    receiver.class_eval do
      #attr_accessor :cache_store
      @@cache_store = AridCache::Store.new
    end
  end
end
