# frozen_string_literal: true

RSpec.describe("Documented response contracts") do
  def fixture(name)
    File.read(File.expand_path("../fixtures/reference/#{name}.json", __dir__), encoding: "UTF-8")
  end

  it "reads the documented records envelope without coercing dates or null clients" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 300 })
      .to_return(body: fixture("records"))
    result = api.records.list(company_id: 1)
    expect(result.items.first[:id]).to(eq(2))
    expect(result.items.first[:datetime]).to(eq("2019-01-16T16:00:00+09:00"))
    expect(result.items.first[:client]).to(be_nil)
    expect(result.items.first[:services].first[:cost]).to(eq(100))
    expect(result.meta).to(eq(page: 1, total_count: 10))
  end

  it "reads search metadata for pagination" do
    stub_request(:post, endpoint("/company/1/clients/search")).to_return(body: fixture("clients_search"))
    result = api.clients.search(company_id: 1, per_page: 3)
    expect(result.items.map { |item| item[:id] }).to(eq([2, 3, 1]))
    expect(result.meta).to(eq(total_count: 908))
    expect(result.next_page?).to(be(true))
  end

  it "preserves service string identifiers and nested fields" do
    stub_request(:get, endpoint("/company/1/services/")).to_return(body: fixture("services"))
    result = api.services.list(company_id: 1)
    expect(result.items.first[:id]).to(eq("79067"))
    expect(result.items.last[:image_group][:images][:basic][:width]).to(eq("372"))
  end

  it "preserves the staff envelope and integer identifiers" do
    stub_request(:get, endpoint("/company/1/staff/")).to_return(body: fixture("staff"))
    result = api.staff.list(company_id: 1)
    expect(result.items.first[:id]).to(eq(1_001_539))
    expect(result.meta).to(eq(total_count: 1))
  end

  it "reads the documented service category collection" do
    stub_request(:get, endpoint("/company/1/service_categories/"))
      .to_return(body: fixture("service_categories"))
    result = api.service_categories.list(company_id: 1)
    expect(result.items.map { |item| item[:id] }).to(eq([345, 3456]))
    expect(result.items.first[:staff]).to(eq([5006, 8901, 26514, 26516, 26519, 26520]))
    expect(result.meta).to(eq(total_count: 2))
  end
end
