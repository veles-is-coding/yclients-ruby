# frozen_string_literal: true

RSpec.describe(Yclients::Resources::Records) do
  it "passes with_deleted through list without changing unspecified requests" do
    request = stub_request(:get, endpoint("/records/1"))
      .with(query: { page: 1, count: 300, with_deleted: true })
      .to_return(body: json_response([{ id: 1, deleted: true }]))

    expect(api.records.list(company_id: 1, with_deleted: true).items).to(eq([{ id: 1, deleted: true }]))
    expect(request).to(have_been_requested.once)
  end

  it "preserves with_deleted on every enumerated page" do
    stub_request(:get, endpoint("/records/1"))
      .with(query: { page: 1, count: 1, with_deleted: true })
      .to_return(body: json_response([{ id: 1, deleted: true }]))
    stub_request(:get, endpoint("/records/1"))
      .with(query: { page: 2, count: 1, with_deleted: true })
      .to_return(body: json_response([]))

    expect(api.records.each(company_id: 1, per_page: 1, with_deleted: true).map { |record| record[:id] }).to(eq([1]))
  end

  it "passes an explicit false value" do
    stub_request(:get, endpoint("/records/1"))
      .with(query: { page: 1, count: 300, with_deleted: false })
      .to_return(body: json_response([]))

    expect(api.records.list(company_id: 1, with_deleted: false).items).to(be_empty)
  end
end
