# frozen_string_literal: true

RSpec.describe("HTTP transport") do
  it "does not retain query parameters or bodies between requests" do
    transport = http_transport
    stub_request(:post, endpoint("/probe")).with(query: { page: 2 }, body: { name: "first" }.to_json)
      .to_return(body: json_response("first"))
    stub_request(:get, endpoint("/probe")).with(body: nil)
      .to_return(body: json_response("second"))

    expect(transport.request(:post, "/probe", params: { page: 2 }, body: { name: "first" }).data).to(eq("first"))
    expect(transport.request(:get, "/probe").data).to(eq("second"))
  end

  it "isolates concurrent requests on the same transport" do
    transport = http_transport
    [1, 2].each do |id|
      stub_request(:post, endpoint("/probe")).with(
        query: { id: id },
        body: { id: id }.to_json,
        headers: { "Authorization" => "Bearer partner-secret, User user-secret" },
      ).to_return do
        Thread.pass
        { body: json_response(id) }
      end
    end

    results = [1, 2].map do |id|
      Thread.new do
        Array.new(5) do
          transport.request(:post, "/probe", params: { id: id }, body: { id: id }).data
        end
      end
    end.map(&:value)

    expect(results).to(eq([Array.new(5, 1), Array.new(5, 2)]))
  end

  it "retains unknown payload fields and recursively symbolizes JSON" do
    stub_request(:get, endpoint("/probe")).to_return(
      status: 201,
      headers: { "X-Request-Id" => "abc" },
      body: json_response([{ id: 2, extra: { enabled: false } }], meta: { count: 1 }, future: "value"),
    )
    result = http_transport.request(:get, "/probe")
    expect(result.data).to(eq([{ id: 2, extra: { enabled: false } }]))
    expect(result.meta).to(eq(count: 1))
    expect(result.payload[:future]).to(eq("value"))
    expect(result.headers["x-request-id"]).to(eq("abc"))
    expect(result.status).to(eq(201))
  end

  [nil, false, 3, "text", [1, 2], { plain: 1 }].each do |payload|
    it "preserves raw JSON #{payload.inspect}" do
      stub_request(:get, endpoint("/probe")).to_return(body: JSON.generate(payload))
      expect(http_transport.request(:get, "/probe").data).to(eq(payload))
    end
  end

  [:post, :put, :patch, :delete].each do |method|
    it "encodes #{method} JSON and normalizes dates without modifying input" do
      body = { date: Date.new(2025, 1, 2), times: [Time.iso8601("2025-01-02T12:00:00+03:00")], nil_value: nil }
      stub_request(method, endpoint("/probe")).with(
        headers: { "Content-Type" => "application/json" },
        body: { date: "2025-01-02", times: ["2025-01-02T12:00:00+03:00"], nil_value: nil }.to_json,
      ).to_return(status: 204)
      expect(http_transport.request(method, "/probe", body: body).data).to(be_nil)
      expect(body[:date]).to(be_a(Date))
    end
  end

  [
    "https://evil.example/test",
    "//evil.example/test",
    "../secret",
    "/a/../secret",
    "/%2e%2e/secret",
    "/test?token=secret",
    "/test#secret",
    "/test\\secret",
  ].each do |path|
    it "rejects unsafe transport path #{path}" do
      expect { http_transport.request(:get, path) }.to(raise_error(Yclients::ConfigurationError))
    end
  end

  it "raises ParseError for invalid JSON from a successful response" do
    stub_request(:get, endpoint("/probe")).to_return(body: "<html>broken</html>")
    expect { http_transport.request(:get, "/probe") }.to(raise_error(Yclients::ParseError))
  end

  it "parses UTF-8 JSON regardless of the transport string's external encoding" do
    body = "{\"data\":{\"name\":\"\u0418\u0432\u0430\u043d\"}}".dup.force_encoding(Encoding::US_ASCII)
    stub_request(:get, endpoint("/probe")).to_return(body: body)
    expect(http_transport.request(:get, "/probe").data[:name]).to(eq("\u0418\u0432\u0430\u043d"))
  end

  it "passes configured read and connection timeouts to Faraday" do
    options = nil
    allow(Faraday).to(receive(:new).and_wrap_original) do |original, *arguments, &block|
      original.call(*arguments, &block).tap { |connection| options = connection.options }
    end
    stub_request(:get, endpoint("/probe")).to_return(body: json_response)
    http_transport(partner_token: "p", timeout: 7, open_timeout: 3).request(:get, "/probe")
    expect(options.timeout).to(eq(7))
    expect(options.open_timeout).to(eq(3))
  end

  {
    401 => :AuthenticationError,
    403 => :ForbiddenError,
    404 => :NotFoundError,
    400 => :ValidationError,
    422 => :ValidationError,
    429 => :RateLimitError,
    500 => :ServerError,
    302 => :ApiError,
    409 => :ApiError,
  }.each do |status, name|
    it "maps HTTP #{status} and preserves diagnostic context" do
      body = { success: false, meta: { message: "problem", errors: { id: ["invalid"] } } }.to_json
      stub_request(:post, endpoint("/probe")).to_return(status: status, body: body, headers: { "X-Trace" => "trace" })
      expect { http_transport.request(:post, "/probe") }.to(raise_error(Yclients.const_get(name)) do |error|
        expect(error.status).to(eq(status))
        expect(error.method).to(eq(:post))
        expect(error.path).to(eq("/probe"))
        expect(error.response_body).to(eq(body))
        expect(error.response_headers["x-trace"]).to(eq("trace"))
        expect(error.details).to(eq(message: "problem", errors: { id: ["invalid"] }))
      end)
    end
  end

  it "maps a non-JSON HTTP error instead of masking it with ParseError" do
    stub_request(:get, endpoint("/probe")).to_return(status: 401, body: "<html>denied</html>")
    expect { http_transport.request(:get, "/probe") }.to(raise_error(Yclients::AuthenticationError) do |e|
      expect(e.response_body).to(eq("<html>denied</html>"))
    end)
  end

  it "raises ApiError for logical failures with HTTP 200" do
    stub_request(:get, endpoint("/probe")).to_return(body: '{"success":false,"data":null,"meta":{"message":"no"}}')
    expect { http_transport.request(:get, "/probe") }.to(raise_error(Yclients::ApiError) { |e| expect(e.status).to(eq(200)) })
  end

  it "does not follow redirects with credentials" do
    stub_request(:get, endpoint("/probe")).to_return(status: 302, headers: { "Location" => "https://evil.example" })
    expect { http_transport.request(:get, "/probe") }.to(raise_error(Yclients::ApiError))
    expect(a_request(:get, "https://evil.example")).not_to(have_been_made)
  end
end
