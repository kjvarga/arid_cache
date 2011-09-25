Gem::Specification.new do |s|
  s.name        = %q{arid_cache}
  s.version     = File.read('VERSION').chomp
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Karl Varga"]
  s.email       = %q{kjvarga@gmail.com}
  s.homepage    = %q{https://github.com/Creagency/arid_cache}
  s.summary     = %q{Automates efficient caching of your ActiveRecord collections, gives you counts for free and supports pagination.}
  s.description = %q{AridCache makes caching easy and effective.  AridCache supports caching on all your model named scopes, class methods and instance methods right out of the box.  AridCache prevents caching logic from cluttering your models and clarifies your logic by making explicit calls to cached result sets.
AridCache is designed for handling large, expensive ActiveRecord collections but is equally useful for caching anything else as well.}

  # Leave it to the Gemfile
  # s.add_development_dependency 'rspec'
  # s.add_development_dependency 'activerecord'
  # s.add_development_dependency 'activesupport'
  # s.add_development_dependency 'sqlite3-ruby'
  # s.add_development_dependency 'ruby-debug'
  # s.add_development_dependency 'ruby-debug-base'
  # s.add_development_dependency 'machinist'
  # s.add_development_dependency "rspec"
  # s.add_development_dependency 'test-unit'
  # s.add_development_dependency 'rr'
  # s.add_development_dependency 'i18n'
  # s.add_development_dependency 'faker'

  s.add_dependency 'will_paginate'
  s.test_files  = Dir.glob(['{test|spec}/**/*']) - Dir['test/log/**/*'] - Dir['test/log*']
  s.files       = Dir.glob(["[A-Z]*", "init.rb", "{lib,rails}/**/*"])
end
