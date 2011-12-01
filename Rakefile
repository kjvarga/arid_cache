# If you see lots of "warning: already initialized constant" warnings from Rake or other
# issues running 'rake spec' or 'rake test', prefix your call with 'bundle exec'.
require 'bundler/setup'
Bundler.require(:default, :development)

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = ['--backtrace']
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :default => :test

#
# Helpers
#

def name;         @name ||= Dir['*.gemspec'].first.split('.').first end
def version;      File.read('VERSION').chomp end
def gemspec_file; "#{name}.gemspec" end
def gem_file;     "#{name}-#{version}.gem" end

#
# Release Tasks
# @see https://github.com/mojombo/rakegem
#

desc "Create tag v#{version}, build the gem and push to Git"
task :release => :build do
  unless `git branch` =~ /^\* master$/
    puts "You must be on the master branch to release!"
    exit!
  end
  sh "git tag v#{version}"
  sh "git push origin master --tags"
end

desc "Build #{gem_file} into the pkg/ directory"
task :build do
  sh "mkdir -p pkg"
  sh "gem build #{gemspec_file}"
  sh "mv #{gem_file} pkg"
  sh "bundle --local"
end
