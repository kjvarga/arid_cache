# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{arid_cache}
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Karl Varga"]
  s.date = %q{2010-01-15}
  s.description = %q{AridCache makes caching easy and effective.  AridCache supports caching on all your model named scopes, class methods and instance methods right out of the box.  AridCache prevents caching logic from cluttering your models and clarifies your logic by making explicit calls to cached result sets.
AridCache is designed for handling large, expensive ActiveRecord collections but is equally useful for caching anything else as well.
}
  s.email = %q{kjvarga@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "arid_cache.gemspec",
     "init.rb",
     "lib/arid_cache.rb",
     "lib/arid_cache/active_record.rb",
     "lib/arid_cache/cache_proxy.rb",
     "lib/arid_cache/helpers.rb",
     "lib/arid_cache/store.rb",
     "rails/init.rb",
     "spec/arid_cache_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "tasks/arid_cache_tasks.rake",
     "test/arid_cache_test.rb",
     "test/console",
     "test/db/prepare.rb",
     "test/db/schema.rb",
     "test/lib/active_support/cache/file_store_extras.rb",
     "test/lib/blueprint.rb",
     "test/log/.gitignore",
     "test/models/company.rb",
     "test/models/user.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/kjvarga/arid_cache}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Automates efficient caching of your ActiveRecord collections, gives you counts for free and supports pagination.}
  s.test_files = [
    "spec/arid_cache_spec.rb",
     "spec/spec_helper.rb",
     "test/arid_cache_test.rb",
     "test/db/prepare.rb",
     "test/db/schema.rb",
     "test/lib/active_support/cache/file_store_extras.rb",
     "test/lib/blueprint.rb",
     "test/models/company.rb",
     "test/models/user.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<will_paginate>, [">= 0"])
      s.add_development_dependency(%q<will_paginate>, [">= 0"])
      s.add_development_dependency(%q<faker>, [">= 0"])
      s.add_development_dependency(%q<machinist>, [">= 0"])
    else
      s.add_dependency(%q<will_paginate>, [">= 0"])
      s.add_dependency(%q<will_paginate>, [">= 0"])
      s.add_dependency(%q<faker>, [">= 0"])
      s.add_dependency(%q<machinist>, [">= 0"])
    end
  else
    s.add_dependency(%q<will_paginate>, [">= 0"])
    s.add_dependency(%q<will_paginate>, [">= 0"])
    s.add_dependency(%q<faker>, [">= 0"])
    s.add_dependency(%q<machinist>, [">= 0"])
  end
end

