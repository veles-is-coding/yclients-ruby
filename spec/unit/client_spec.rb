# frozen_string_literal: true

RSpec.describe(Yclients::Client) do
  it "does not expose arbitrary endpoint requests" do
    expect(api).not_to(respond_to(:raw, :request, :get, :post, :transport))
    expect(Yclients.const_defined?(:Raw, false)).to(be(false))
  end

  it "builds partner-only headers and preserves the API prefix" do
    request = stub_request(:get, endpoint("/company/1/")).with(headers: {
      "Authorization" => "Bearer partner-secret", "Accept" => "application/vnd.yclients.v2+json",
    }).to_return(body: json_response({ id: 1 }))
    result = described_class.new(partner_token: "partner-secret").companies.retrieve(company_id: 1)
    expect(result.data).to(eq(id: 1))
    expect(request).to(have_been_requested.once)
  end

  it "copies credentials and derives a separate tenant client" do
    partner = +"partner-secret"
    user = +"tenant-secret"
    base = described_class.new(partner_token: partner)
    tenant = base.with_user_token(user)
    partner.replace("changed")
    user.replace("changed")
    stub_request(:get, endpoint("/company/1/")).with(headers: { "Authorization" => "Bearer partner-secret" })
      .to_return(body: json_response("base"))
    stub_request(:get, endpoint("/company/1/")).with(headers: {
      "Authorization" => "Bearer partner-secret, User tenant-secret",
    }).to_return(body: json_response("tenant"))
    expect(base.companies.retrieve(company_id: 1).data).to(eq("base"))
    expect(tenant.companies.retrieve(company_id: 1).data).to(eq("tenant"))
    expect(base).not_to(respond_to(:user_token=, :partner_token=, :base_url=))
  end

  [nil, "", " ", "token\r\nInjected: yes", "token, User other"].each do |token|
    it "rejects invalid partner credentials #{token.inspect}" do
      expect { described_class.new(partner_token: token) }.to(raise_error(Yclients::ConfigurationError))
    end
  end

  [0, -1, nil, Float::INFINITY, "10"].each do |timeout|
    it "rejects invalid timeouts #{timeout.inspect}" do
      expect { described_class.new(partner_token: "p", timeout: timeout) }.to(raise_error(Yclients::ConfigurationError))
    end
  end

  ["https://user:pass@example.com/api", "ftp://example.com", "https://example.com/?secret=x"].each do |url|
    it "rejects unsuitable base URLs #{url}" do
      expect { described_class.new(partner_token: "p", base_url: url) }.to(raise_error(Yclients::ConfigurationError))
    end
  end

  it "honors custom base URL and timeout options" do
    client = described_class.new(
      partner_token: "p",
      base_url: "https://example.com/custom/",
      timeout: 7,
      open_timeout: 3,
    )
    stub_request(:get, "https://example.com/custom/company/1/").to_return(body: json_response)
    expect(client.companies.retrieve(company_id: 1).status).to(eq(200))
    expect(client.configuration.timeout).to(eq(7))
    expect(client.configuration.open_timeout).to(eq(3))
    expect(client.configuration).to(be_frozen)
  end

  it "does not reveal credentials through inspect" do
    expect([
      api.inspect,
      api.configuration.inspect,
      api.companies.inspect,
    ].join).not_to(include("partner-secret", "user-secret"))
  end

  it "keeps concurrent tenant requests isolated" do
    base = described_class.new(partner_token: "p")
    clients = ["first", "second"].map { |token| base.with_user_token(token) }
    ["first", "second"].each do |token|
      stub_request(:get, endpoint("/company/1/")).with(headers: { "Authorization" => "Bearer p, User #{token}" })
        .to_return(body: json_response(token))
    end
    results = clients.map do |client|
      Thread.new do
        Array.new(5) do
          client.companies.retrieve(company_id: 1).data
        end
      end
    end.map(&:value)
    expect(results).to(eq([Array.new(5, "first"), Array.new(5, "second")]))
  end

  it "accepts an injectable transport factory and uses it for derived clients" do
    configurations = []
    factory = lambda do |config|
      configurations << config
      Object.new.tap do |transport|
        def transport.request(method, path, params: {}, body: nil)
          Yclients::Response.new(payload: { data: [method, path, params, body] }, status: 200, headers: {})
        end
      end
    end
    client = described_class.new(partner_token: "p", transport: factory)
    result = client.with_user_token("u").companies.retrieve(company_id: 1)
    expect(result.data).to(eq([:get, "/company/1/", {}, nil]))
    expect(configurations.map(&:user_token)).to(eq([nil, "u"]))
  end
end
