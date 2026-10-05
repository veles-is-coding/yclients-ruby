# frozen_string_literal: true

RSpec.describe("Pagination") do
  it "returns the resource after block iteration" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 300 })
      .to_return(body: json_response([{ id: 1 }]))
    resource = api.records
    pages = []

    expect(resource.each(company_id: 1) { |record| record[:id] }).to(equal(resource))
    expect(resource.each_page(company_id: 1) { |page| pages << page.items }).to(equal(resource))
    expect(pages).to(eq([[{ id: 1 }]]))
  end

  it "fetches pages lazily and honors an early break" do
    first = stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 1 })
      .to_return(body: json_response([{ id: 2 }]))
    next_page = stub_request(:get, endpoint("/records/1")).with(query: { page: 3, count: 1 })
      .to_return(body: json_response([{ id: 3 }]))
    pages = api.records.each_page(company_id: 1, page: 2, per_page: 1)

    expect(pages).to(be_an(Enumerator))
    expect(first).not_to(have_been_requested)
    result = pages.each { |page| break page.items }

    expect(result).to(eq([{ id: 2 }]))
    expect(first).to(have_been_requested.once)
    expect(next_page).not_to(have_been_requested)
  end

  it "does no HTTP work until an enumerator is consumed and stops when the consumer stops" do
    first = stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 2 })
      .to_return(body: json_response(
        [{ id: 1 }, { id: 2 }],
        meta: { total_count: 4 },
      ))
    second = stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 2 })
      .to_return(body: json_response(
        [{ id: 3 }, { id: 4 }],
        meta: { total_count: 4 },
      ))
    records = api.records.each(company_id: 1, per_page: 2)
    expect(records).to(be_an(Enumerator))
    expect(first).not_to(have_been_requested)
    expect(records.lazy.take(1).to_a).to(eq([{ id: 1 }]))
    expect(first).to(have_been_requested.once)
    expect(second).not_to(have_been_requested)
  end

  it "iterates records from the requested starting page" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 2, staff_id: 9 })
      .to_return(body: json_response(
        [{ id: 3 }, { id: 4 }],
        meta: { total_count: 5 },
      ))
    stub_request(:get, endpoint("/records/1")).with(query: { page: 3, count: 2, staff_id: 9 })
      .to_return(body: json_response([{ id: 5 }], meta: { total_count: 5 }))
    pages = api.records.each_page(company_id: 1, page: 2, per_page: 2, staff_id: 9).to_a
    expect(pages.map(&:items)).to(eq([[{ id: 3 }, { id: 4 }], [{ id: 5 }]]))
    expect(pages.map(&:next_page?)).to(eq([true, false]))
  end

  it "does not stop records iteration when total_count describes only the current page" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 2 })
      .to_return(body: json_response(
        [{ id: 1 }, { id: 2 }],
        meta: { page: 1, total_count: 2 },
      ))
    stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 2 })
      .to_return(body: json_response(
        [{ id: 3 }],
        meta: { page: 2, total_count: 1 },
      ))

    expect(api.records.each(company_id: 1, per_page: 2).map { |record| record[:id] }).to(eq([1, 2, 3]))
  end

  it "checks an empty page after a full final records page even if a total is supplied" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 2 })
      .to_return(body: json_response(
        [{ id: 1 }, { id: 2 }],
        meta: { total_count: 2 },
      ))
    final = stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 2 })
      .to_return(body: json_response([], meta: { total_count: 2 }))

    expect(api.records.each(company_id: 1, per_page: 2).map { |record| record[:id] }).to(eq([1, 2]))
    expect(final).to(have_been_requested.once)
  end

  it "still stops client search on a full final page using its documented overall total" do
    request = stub_request(:post, endpoint("/company/1/clients/search"))
      .with(body: { page: 2, page_size: 2, filters: [] }.to_json)
      .to_return(body: json_response([{ id: 3 }, { id: 4 }], meta: { total_count: 4 }))

    expect(api.clients.each(company_id: 1, page: 2, per_page: 2).map { |client| client[:id] }).to(eq([3, 4]))
    expect(request).to(have_been_requested.once)
  end

  it "supports block iteration and stops at an empty page despite stale totals" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 2 })
      .to_return(body: json_response(
        [{ id: 1 }, { id: 2 }],
        meta: { total_count: 100 },
      ))
    stub_request(:get, endpoint("/records/1")).with(query: { page: 2, count: 2 })
      .to_return(body: json_response([], meta: { total_count: 100 }))
    ids = []
    api.records.each(company_id: 1, per_page: 2) { |record| ids << record[:id] }
    expect(ids).to(eq([1, 2]))
  end

  it "uses page length when totals are missing and ignores meta.count as a total" do
    stub_request(
      :post,
      endpoint("/company/1/clients/search"),
    ).with(body: { page: 1, page_size: 2, filters: [] }.to_json)
      .to_return(body: json_response(
        [{ id: 1 }, { id: 2 }],
        meta: { count: 2 },
      ))
    stub_request(
      :post,
      endpoint("/company/1/clients/search"),
    ).with(body: { page: 2, page_size: 2, filters: [] }.to_json)
      .to_return(body: json_response([{ id: 3 }], meta: []))
    expect(api.clients.each(company_id: 1, per_page: 2).map { |r| r[:id] }).to(eq([1, 2, 3]))
  end

  it "does not silently treat a malformed collection response as an empty page" do
    stub_request(:get, endpoint("/records/1")).with(query: { page: 1, count: 300 })
      .to_return(body: json_response({ unexpected: [] }))
    expect { api.records.list(company_id: 1) }.to(raise_error(Yclients::ResponseError))
  end

  [0, -1, nil, "2", 1.5].each do |value|
    it "rejects invalid pagination #{value.inspect}" do
      expect { api.records.list(company_id: 1, page: value) }.to(raise_error(Yclients::ConfigurationError))
      expect { api.records.list(company_id: 1, per_page: value) }.to(raise_error(Yclients::ConfigurationError))
    end
  end
end
