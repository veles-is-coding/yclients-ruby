# frozen_string_literal: true

require "yclients"
require "webmock/rspec"
require "json"
require "date"
require "time"
require "logger"
require "stringio"

WebMock.disable_net_connect!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
  unless ARGV.any? { |argument| argument.include?("spec/integration") }
    config.exclude_pattern = "spec/integration/**/*_spec.rb"
  end
  config.order = :random

  config.include(Module.new do
    def api
      Yclients::Client.new(partner_token: "partner-secret", user_token: "user-secret")
    end

    def http_transport(**options)
      configuration = Yclients::Configuration.new(partner_token: "partner-secret", user_token: "user-secret", **options)
      Yclients::Transport::Faraday.new(configuration)
    end

    def endpoint(path)
      "https://api.yclients.com/api/v1#{path}"
    end

    def json_response(data = {}, meta: {}, **extra)
      JSON.generate({ success: true, data: data, meta: meta }.merge(extra))
    end
  end)

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end
end
