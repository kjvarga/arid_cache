$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'arid_cache'
require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'will_paginate'

Spec::Runner.configure do |config|
  
end
