module AridCache
  class Railtie < Rails::Railtie
    
    initializer 'arid_cache.init' do
      ActiveSupport.on_load(:active_record) do
        include AridCache::ActiveRecord
      end
    end
    
  end
end