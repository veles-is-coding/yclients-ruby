# frozen_string_literal: true

RSpec.describe("Resource adapters") do
  it "authorizes without mutating client authentication" do
    client = api
    stub_request(:post, endpoint("/auth")).with(body: { login: "login", password: "password" }.to_json)
      .to_return(body: json_response({ user_token: "new-token", future: 1 }))
    result = client.auth.authorize(login: "login", password: "password")
    expect(result.user_token).to(eq("new-token"))
    expect(result.data[:future]).to(eq(1))
    expect(client.configuration.user_token).to(eq("user-secret"))
    expect(client.auth.inspect).not_to(include("password", "partner-secret"))
  end

  it "preserves an auth challenge without pretending a token was returned" do
    stub_request(:post, endpoint("/auth")).to_return(body: json_response({ uuid: "challenge", flow: "login" }))
    result = api.auth.authorize(login: "login", password: "password")
    expect(result.user_token).to(be_nil)
    expect(result.data[:uuid]).to(eq("challenge"))
  end

  {
    companies: ["/company/1/", { company_id: 1 }],
    clients: ["/client/1/2", { company_id: 1, client_id: 2 }],
    records: ["/record/1/2", { company_id: 1, record_id: 2 }],
    services: ["/company/1/services/2", { company_id: 1, service_id: 2 }],
    staff: ["/company/1/staff/2", { company_id: 1, staff_id: 2 }],
    permissions: ["/user/permissions/1", { company_id: 1 }],
  }.each do |resource, (path, arguments)|
    it "retrieves #{resource} through the documented endpoint" do
      stub_request(:get, endpoint(path)).to_return(body: json_response({ id: 2, custom: "field" }))
      expect(api.public_send(resource).retrieve(**arguments).data).to(eq(id: 2, custom: "field"))
    end
  end

  it "passes company filters and maps per_page to count" do
    stub_request(:get, endpoint("/companies")).with(query: { page: 2, count: 10, my: 1 })
      .to_return(body: json_response([{ id: 1 }], meta: { total_count: 11 }))
    result = api.companies.list(my: 1, page: 2, per_page: 10)
    expect(result.items).to(eq([{ id: 1 }]))
    expect(result.next_page?).to(be(false))
  end

  it "normalizes records dates and omits unspecified filters" do
    stub_request(:get, endpoint("/records/1")).with(query: {
      page: 1, count: 300, client_id: 2, start_date: "2025-01-01", end_date: "2025-01-02T14:30:00+03:00",
    }).to_return(body: json_response(
      [{ id: 5 }],
      meta: { total_count: 1 },
    ))
    result = api.records.list(
      company_id: 1,
      client_id: 2,
      start_date: Date.new(2025, 1, 1),
      end_date: DateTime.iso8601("2025-01-02T14:30:00+03:00"), # rubocop:disable Style/DateTime -- Public API accepts DateTime inputs.
    )
    expect(result.items).to(eq([{ id: 5 }]))
    expect(result.next_page?).to(be(false))
  end

  it "sends client search filters in JSON with page_size" do
    filters = [{ type: "birthday", state: { from: Date.new(2025, 1, 1) } }]
    stub_request(:post, endpoint("/company/1/clients/search")).with(body: {
      page: 3,
      page_size: 2,
      fields: ["id"],
      filters: [{
        type: "birthday", state: { from: "2025-01-01" },
      }],
    }).to_return(body: json_response(
      [{ id: 5 }],
      meta: { total_count: 5 },
    ))
    result = api.clients.search(company_id: 1, filters: filters, fields: ["id"], page: 3, per_page: 2)
    expect(result.items).to(eq([{ id: 5 }]))
    expect(result.next_page?).to(be(false))
    expect(filters.first[:state][:from]).to(be_a(Date))
  end

  it "normalizes the specified empty filter hash to the API's filter array" do
    stub_request(
      :post,
      endpoint("/company/1/clients/search"),
    ).with(body: { page: 1, page_size: 100, filters: [] }.to_json)
      .to_return(body: json_response([]))
    expect(api.clients.search(company_id: 1).items).to(eq([]))
  end

  it "does not retry the POST search endpoint" do
    request = stub_request(:post, endpoint("/company/1/clients/search")).to_return(status: 503)
    expect { api.clients.search(company_id: 1) }.to(raise_error(Yclients::ServerError))
    expect(request).to(have_been_requested.once)
  end

  it "rejects search page sizes above the API limit to avoid silently truncating iteration" do
    expect { api.clients.search(company_id: 1, per_page: 201) }.to(raise_error(Yclients::ConfigurationError))
  end

  it "gets services from the current collection route with filters" do
    stub_request(:get, endpoint("/company/1/services/")).with(query: { staff_id: 2, category_id: 3 })
      .to_return(body: json_response([{ id: 4 }]))
    page = api.services.list(company_id: 1, staff_id: 2, category_id: 3)
    expect(page.items).to(eq([{ id: 4 }]))
    expect(page.next_page?).to(be(false))
  end

  it "gets staff from the current collection route" do
    stub_request(:get, endpoint("/company/1/staff/")).to_return(body: json_response([{ id: 4 }]))
    expect(api.staff.list(company_id: 1).items).to(eq([{ id: 4 }]))
  end

  it "maps permission groups to bracketed query parameters" do
    stub_request(:get, endpoint("/user/permissions/1")).with(query: { "group_permissions" => ["settings", "finances"] })
      .to_return(body: json_response({ settings: {} }))
    expect(api.permissions.retrieve(company_id: 1, groups: ["settings", "finances"]).data).to(eq(settings: {}))
  end

  [nil, 0, -1, "../2", "2?secret=x"].each do |id|
    it "rejects invalid identifiers #{id.inspect} before HTTP" do
      expect { api.records.retrieve(company_id: 1, record_id: id) }.to(raise_error(Yclients::ConfigurationError))
    end
  end
end
