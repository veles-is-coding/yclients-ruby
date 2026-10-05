# frozen_string_literal: true

require_relative "lib/yclients/version"

Gem::Specification.new do |spec|
  spec.name = "yclients"
  spec.version = Yclients::VERSION
  spec.authors = ["Maxim Yurkov"]
  spec.email = ["maxutka7g@gmail.com"]
  spec.summary = "Unofficial Ruby client for the YCLIENTS API"
  spec.description = "A framework-independent YCLIENTS client with immutable authentication, " \
    "pagination and safe retries."
  spec.homepage = "https://github.com/veles-is-coding/yclients-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
  }
  spec.files = Dir.chdir(__dir__) { Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE.txt", "examples/*.rb"] }
  spec.require_paths = ["lib"]
  spec.add_dependency("faraday", "~> 2.0")
end
