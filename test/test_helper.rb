$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib')) # AridCache lib
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))       # test lib

require 'fileutils'
require 'rubygems'
require 'active_record'
require 'active_support'
require 'active_support/test_case'
require 'test/unit' # required by ActiveSupport::TestCase
require 'will_paginate'
require 'ruby-debug'

# Add support for expiring file-cache store.
require 'active_support/cache/file_store_extras'

# Activate ARID Cache
require 'arid_cache'
AridCache.init_rails

# Setup logging
log = File.expand_path(File.join(File.dirname(__FILE__), 'log', 'test.log'))
RAILS_DEFAULT_LOGGER = ENV["STDOUT"] ? Logger.new(STDOUT) : Logger.new(log)

# Setup the cache. Use the file-store cache because the
# memory-store cache doesn't delete cache keys...I don't know why.
RAILS_CACHE = ActiveSupport::Cache.lookup_store(:file_store, "#{File.dirname(__FILE__)}/tmp/cache")

# Mock Rails
Rails = Class.new do
  cattr_accessor :logger, :cache
  def self.cache
    return RAILS_CACHE
  end
  def self.logger
    return RAILS_DEFAULT_LOGGER
  end
end

# Set loggers for all frameworks
for framework in ([ :active_record, :action_controller, :action_mailer ])
  if Object.const_defined?(framework.to_s.camelize)
    framework.to_s.camelize.constantize.const_get("Base").logger = Rails.logger
  end
end
ActiveSupport::Dependencies.logger = Rails.logger
Rails.cache.logger = Rails.logger

# Include this last otherwise the logger isn't set properly
require 'db/prepare'

ActiveRecord::Base.logger.info("#{"="*25} RUNNING UNIT TESTS #{"="*25}\n\t\t\t#{Time.now.to_s}\n#{"="*70}")


