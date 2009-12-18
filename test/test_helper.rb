require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'test/unit' # required by ActiveSupport::TestCase
require 'lib/active_record_test'
require 'db/prepare'


# Mock the Rails cache with an in memory-cache
silence_warnings { Object.const_set "RAILS_CACHE", ActiveSupport::Cache.lookup_store(:memory_store) }
Rails = Class.new { def self.cache; return RAILS_CACHE; end }

ActiveRecord::Base.logger = Logger.new(open(File.join(File.dirname(__FILE__), 'log', 'test.log')))
