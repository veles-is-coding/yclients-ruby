# frozen_string_literal: true

RSpec.describe(Yclients::Resources::Records) do
  it "passes a modification window and deleted flag on every page" do
    window = { changed_after: "2026-10-09T10:00:00Z", changed_before: "2026-10-09T10:15:00Z" }
    stub_request(:get, endpoint("/records/1"))
      .with(query: window.merge(page: 1, count: 1, with_deleted: true))
      .to_return(body: json_response([{ id: 2, deleted: true }]))
    stub_request(:get, endpoint("/records/1"))
      .with(query: window.merge(page: 2, count: 1, with_deleted: true))
      .to_return(body: json_response([]))

    expect(api.records.each(company_id: 1, per_page: 1, with_deleted: true, **window).map { |row| row[:id] }).to(eq([2]))
  end

  it "accepts a single modification boundary" do
    stub_request(:get, endpoint("/records/1"))
      .with(query: { page: 1, count: 300, changed_after: "2026-10-09T10:00:00Z" })
      .to_return(body: json_response([]))

    expect(api.records.list(company_id: 1, changed_after: "2026-10-09T10:00:00Z").items).to(be_empty)
  end
end
