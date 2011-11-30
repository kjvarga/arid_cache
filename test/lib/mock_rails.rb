require 'logger'
require 'fix_active_support_file_store_expires_in'
require 'active_record'

root_path = File.expand_path(File.join(File.dirname(__FILE__), '../../'))
RAILS_DEFAULT_LOGGER = ENV["STDOUT"] ? Logger.new(STDOUT) : Logger.new(File.join(root_path, '/test/log/test.log'))
FileUtils.mkdir_p(File.join(root_path, 'tmp/cache'))
RAILS_CACHE = ActiveSupport::Cache.lookup_store(:file_store, File.join(root_path, 'tmp/cache'))

# Mock Rails
Rails = Class.new do
  cattr_accessor :logger, :cache
  def self.cache
    return RAILS_CACHE
  end
  def self.logger
    return RAILS_DEFAULT_LOGGER
  end
  def self.rails3?
    ActiveRecord::VERSION::STRING.to_i >= 3
  rescue
    false
  end
end

# Set loggers for all frameworks
for framework in ([ :active_record, :action_controller, :action_mailer ])
  if Object.const_defined?(framework.to_s.camelize)
    framework.to_s.camelize.constantize.const_get("Base").logger = Rails.logger
  end
end
ActiveSupport::Dependencies.logger = Rails.logger if defined?(ActiveSupport::Dependencies)
Rails.cache.logger = Rails.logger

# Include this last otherwise the logger isn't set properly
require 'db_prepare'
