$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib')) # make requiring from test/lib easy

require 'fileutils'
require 'rubygems'
require 'thread'
require 'bundler/setup'
Bundler.require
require 'test/unit' # required by ActiveSupport::TestCase
require 'active_support/test_case'

require 'mock_rails'
require 'blueprint'
require 'add_query_counting_to_active_record'

require 'will_paginate/version'
if WillPaginate::VERSION::MAJOR < 3
  WillPaginate.enable_activerecord
else
  require 'will_paginate/array'
  require 'will_paginate/active_record'
end

AridCache.framework.init
Blueprint.seeds

ActiveRecord::Base.logger && ActiveRecord::Base.logger.info("#{"="*25} RUNNING UNIT TESTS #{"="*25}\n\t\t\t#{Time.now.to_s}\n#{"="*70}")
Array.class_eval { alias count size } if RUBY_VERSION < '1.8.7'
