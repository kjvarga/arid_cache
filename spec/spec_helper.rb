root_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$LOAD_PATH.unshift(File.join(root_path, '/test/lib')) # add test/lib to the load path

require 'bundler/setup'
Bundler.require

require 'spec/autorun'
require 'mock_rails'
require 'blueprint'

WillPaginate.enable_activerecord
AridCache.init_rails

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

Spec::Runner.configure do |config|
  include ActiveRecordQueryMatchers
  config.mock_with :mocha

  config.before(:all) do
    Sham.reset(:before_all)
  end

  config.before(:each) do
    Sham.reset(:before_each)
    full_example_description = "#{self.class.description} #{@method_name}"
    RAILS_DEFAULT_LOGGER.info("\n\n#{full_example_description}\n#{'-' * (full_example_description.length)}")
  end
end