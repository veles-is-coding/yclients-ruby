# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Yclients::Transport::Faraday) do
  around do |example|
    previous = described_class.request_limiter if described_class.respond_to?(:request_limiter)
    example.run
  ensure
    described_class.request_limiter = previous if described_class.respond_to?(:request_limiter=)
  end

  it "wraps every HTTP retry and preserves the final response" do
    attempts = 0
    inside_limiter = false
    limiter = lambda do |&request|
      attempts += 1
      inside_limiter = true
      request.call
    ensure
      inside_limiter = false
    end
    described_class.request_limiter = limiter
    allow_any_instance_of(described_class).to(receive(:sleep))
    stub_request(:get, endpoint("/company/42/")).to_return do
      expect(inside_limiter).to(be(true))
      status = [503, 429, 200].fetch(attempts - 1)
      { status: status, body: json_response({ id: 42 }) }
    end

    expect(api.companies.retrieve(company_id: 42).data[:id]).to(eq(42))
    expect(attempts).to(eq(3))
  end

  it "applies the limiter to a retry after a connection failure" do
    attempts = 0
    described_class.request_limiter = ->(&request) {
      attempts += 1
      request.call
    }
    allow_any_instance_of(described_class).to(receive(:sleep))
    stub_request(:get, endpoint("/company/42/")).to_timeout.then.to_return(body: json_response({ id: 42 }))

    expect(api.companies.retrieve(company_id: 42).data[:id]).to(eq(42))
    expect(attempts).to(eq(2))
  end

  it "does not send an HTTP request when the limiter raises" do
    described_class.request_limiter = ->(&_request) { raise "shared limiter unavailable" }
    request = stub_request(:get, endpoint("/company/42/")).to_return(body: json_response({ id: 42 }))

    expect { api.companies.retrieve(company_id: 42) }.to(raise_error(RuntimeError, "shared limiter unavailable"))
    expect(request).not_to(have_been_requested)
  end

  it "applies one shared hook to clients created before configuration and token clones" do
    original = api
    clone = original.with_user_token("another-user")
    attempts = 0
    described_class.request_limiter = ->(&request) {
      attempts += 1
      request.call
    }
    stub_request(:get, endpoint("/company/42/")).to_return(body: json_response({ id: 42 }))

    original.companies.retrieve(company_id: 42)
    clone.companies.retrieve(company_id: 42)
    expect(attempts).to(eq(2))
  end

  it "limits a failed mutation without retrying it" do
    attempts = 0
    described_class.request_limiter = ->(&request) {
      attempts += 1
      request.call
    }
    stub_request(:post, endpoint("/records/42")).to_return(status: 503, body: json_response)

    expect { http_transport.request(:post, "/records/42", body: { client_id: 1 }) }
      .to(raise_error(Yclients::ServerError))
    expect(attempts).to(eq(1))
  end

  it "rejects a limiter that cannot wrap a request" do
    expect { described_class.request_limiter = Object.new }
      .to(raise_error(Yclients::ConfigurationError, /call/))
  end

  it "allows explicitly disabling the hook" do
    described_class.request_limiter = ->(&_request) { raise "must not run" }
    described_class.request_limiter = nil
    stub_request(:get, endpoint("/company/42/")).to_return(body: json_response({ id: 42 }))

    expect(api.companies.retrieve(company_id: 42).data[:id]).to(eq(42))
  end
end
