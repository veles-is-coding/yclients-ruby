# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Validate RBS signatures"
task :signatures do
  sh "bundle exec rbs -I sig -r date validate"
end

task default: [:spec, :rubocop, :signatures]
