# frozen_string_literal: true

RSpec.describe("Retry and logging policy") do
  before do
    allow_any_instance_of(Yclients::Transport::Faraday).to(receive(:sleep))
  end

  [429, 502, 503, 504].each do |status|
    [:get, :head].each do |method|
      it "retries #{method} after HTTP #{status} at most twice" do
        request = stub_request(method, endpoint("/probe")).to_return(status: status, body: "gateway")
        expect { http_transport.request(method, "/probe") }.to(raise_error(Yclients::ApiError))
        expect(request).to(have_been_requested.times(3))
      end
    end
  end

  [Faraday::TimeoutError, Faraday::ConnectionFailed].each do |failure|
    it "recovers from a transient #{failure}" do
      request = stub_request(:get, endpoint("/probe")).to_raise(failure).then.to_return(body: json_response("ok"))
      expect(http_transport.request(:get, "/probe").data).to(eq("ok"))
      expect(request).to(have_been_requested.twice)
    end
  end

  {
    Faraday::TimeoutError => Yclients::TimeoutError,
    Faraday::ConnectionFailed => Yclients::ConnectionError,
  }.each do |failure, error|
    it "maps exhausted #{failure} to the SDK hierarchy" do
      request = stub_request(:get, endpoint("/probe")).to_raise(failure)
      expect { http_transport.request(:get, "/probe") }.to(raise_error(error))
      expect(request).to(have_been_requested.times(3))
    end
  end

  [:post, :put, :patch, :delete].each do |method|
    [429, 503, Faraday::TimeoutError, Faraday::ConnectionFailed].each do |failure|
      it "never retries #{method} on #{failure}" do
        request = stub_request(method, endpoint("/probe"))
        failure.is_a?(Integer) ? request.to_return(status: failure) : request.to_raise(failure)
        expect { http_transport.request(method, "/probe") }.to(raise_error(Yclients::Error))
        expect(request).to(have_been_requested.once)
      end
    end
  end

  it "does not retry a permanent HTTP or parse failure" do
    request = stub_request(:get, endpoint("/probe")).to_return(status: 500, body: "error")
    expect { http_transport.request(:get, "/probe") }.to(raise_error(Yclients::ServerError))
    expect(request).to(have_been_requested.once)
  end

  it "uses bounded exponential backoff with jitter" do
    delays = []
    allow_any_instance_of(Yclients::Transport::Faraday).to(receive(:sleep) { |_transport, delay| delays << delay })
    stub_request(:get, endpoint("/probe")).to_return(status: 503).times(2).then.to_return(body: json_response)
    http_transport.request(:get, "/probe")
    expect(delays.length).to(eq(2))
    expect(delays[0]).to(be_between(0.25, 0.5))
    expect(delays[1]).to(be_between(0.5, 1.0))
  end

  it "records request metadata without query, credentials, path identifiers, or bodies" do
    output = StringIO.new
    transport = http_transport(
      partner_token: "partner-secret",
      user_token: "user-secret",
      logger: Logger.new(output),
    )
    stub_request(:post, endpoint("/auth")).with(query: { phone: "79991234567" })
      .to_return(body: json_response({ user_token: "new-secret" }))
    transport.request(:post, "/auth", params: { phone: "79991234567" }, body: { password: "password-secret" })
    stub_request(:get, endpoint("/clients/person@example.com"))
      .to_return(body: json_response({ email: "private@example.com" }))
    transport.request(:get, "/clients/person@example.com")
    expect(output.string).to(include("POST", "/auth", "status=200", "duration=", "retries=0"))
    expect(output.string).not_to(include(
      "partner-secret",
      "user-secret",
      "new-secret",
      "password-secret",
      "79991234567",
      "person@example.com",
      "private@example.com",
    ))
  end

  it "logs failed attempts and retry count without network exception text" do
    output = StringIO.new
    transport = http_transport(partner_token: "p", logger: Logger.new(output))
    stub_request(:get, endpoint("/records/1")).to_raise(Faraday::TimeoutError.new("private-secret"))
      .then.to_return(body: json_response)
    transport.request(:get, "/records/1")
    expect(output.string).to(include("status=none", "retries=0", "status=200", "retries=1"))
    expect(output.string).not_to(include("private-secret"))
  end

  it "does not retry a successful request when its logger fails" do
    logger = Object.new
    def logger.info(_message)
      raise IOError, "logging unavailable"
    end
    request = stub_request(:get, endpoint("/probe")).to_return(body: json_response("ok"))
    transport = http_transport(partner_token: "p", logger: logger)
    expect(transport.request(:get, "/probe").data).to(eq("ok"))
    expect(request).to(have_been_requested.once)
  end
end
