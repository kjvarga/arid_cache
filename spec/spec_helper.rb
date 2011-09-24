# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
root_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$LOAD_PATH.unshift(File.join(root_path, '/test/lib')) # add test/lib to the load path

require 'bundler/setup'
Bundler.require

require 'mock_rails'
require 'blueprint'
AridCache.framework.init

require 'will_paginate/version'
if WillPaginate::VERSION::MAJOR < 3
  WillPaginate.enable_activerecord
else
  require 'will_paginate/array'
  require 'will_paginate/active_record'
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(root_path, "spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  include ActiveRecordQueryMatchers
  config.mock_with :rr

  config.before(:all) do
    Sham.reset(:before_all)
  end

  config.before(:each) do
    AridCache.store.delete! # so no options get stored and interfere with other tests
    Rails.cache.respond_to?(:clear) ? Rails.cache.clear : Rails.cache.delete_matched(/.*/)
    Sham.reset(:before_each)
    full_example_description = "#{self.class.description} #{@method_name}"
    RAILS_DEFAULT_LOGGER.info("\n\n#{full_example_description}\n#{'-' * (full_example_description.length)}")
  end
end
