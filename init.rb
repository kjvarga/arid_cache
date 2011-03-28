begin
  require File.join(File.dirname(__FILE__), 'lib', 'arid_cache') # From here
rescue LoadError
  require 'arid_cache' # From gem
end
AridCache.init_rails if defined?(Rails)
