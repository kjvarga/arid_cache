$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'rails'
require 'active_support'
require 'active_support/test_case'
require 'test/unit' # required by ActiveSupport::TestCase
require 'db/prepare'
require 'will_paginate'
require 'arid_cache'

# Mock the Rails cache with an in memory-cache
silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(:memory_store) }
Rails = Class.new { def self.cache; return RAILS_CACHE; end }

log = File.expand_path(File.join(File.dirname(__FILE__), 'log', 'test.log'))

ActiveRecord::Base.logger = ENV["STDOUT"] ? Logger.new(STDOUT) : Logger.new(log)
ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.logger.info("#{"="*25} RUNNING UNIT TESTS #{"="*25}\n\t\t\t#{Time.now.to_s}\n#{"="*70}")
RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
#Rails::Initializer.run do |config|
#  config.log_level = :debug
#  config.log_path = log
#  config.cache_store :memory_store
#end