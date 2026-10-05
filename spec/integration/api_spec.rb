# frozen_string_literal: true

RSpec.describe("Live YCLIENTS contracts", :live) do
  let(:live_api) do
    Yclients::Client.new(
      partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"),
      user_token: ENV.fetch("YCLIENTS_USER_TOKEN"),
    )
  end
  let(:company_id) { ENV.fetch("YCLIENTS_COMPANY_ID") }

  around do |example|
    required = ["YCLIENTS_PARTNER_TOKEN", "YCLIENTS_USER_TOKEN", "YCLIENTS_COMPANY_ID"]
    skip("Set YCLIENTS_PARTNER_TOKEN, YCLIENTS_USER_TOKEN and YCLIENTS_COMPANY_ID") unless required.all? do |key|
      !ENV.fetch(key, "").empty?
    end
    WebMock.allow_net_connect!
    sleep(0.3)
    example.run
  ensure
    WebMock.disable_net_connect!
  end

  def check_response(response)
    expect(response.status.between?(200, 299)).to(be(true))
    expect(response.payload.is_a?(Hash)).to(be(true))
    expect(response.payload[:success]).to(be(true))
  end

  def check_collection(response)
    check_response(response)
    expect(response.items.is_a?(Array)).to(be(true))
    expect(response.items.all? { |item| item.is_a?(Hash) && item.key?(:id) }).to(be(true))
  end

  def check_retrieval(resource, response, id_key)
    item = response.items.first
    skip("Test account needs at least one #{resource} item for retrieval") unless item
    sleep(0.3)
    retrieved = live_api.public_send(resource).retrieve(company_id: company_id, id_key => item.fetch(:id))
    check_response(retrieved)
    data = retrieved.data
    data = data.first if data.is_a?(Array)
    expect(data.is_a?(Hash) && data[:id].to_s == item[:id].to_s).to(be(true))
  end

  it "lists companies available to the user" do
    check_collection(live_api.companies.list(my: 1, per_page: 2))
  end

  it "retrieves a company" do
    response = live_api.companies.retrieve(company_id: company_id)
    check_response(response)
    expect(response.data.is_a?(Hash)).to(be(true))
    expect(response.data[:id].to_s == company_id).to(be(true))
  end

  it "searches and retrieves clients using the non-deprecated search contract" do
    response = live_api.clients.search(company_id: company_id, per_page: 2, fields: ["id"])
    check_collection(response)
    expect(response.meta.is_a?(Hash) && response.meta[:total_count].is_a?(Integer)).to(be(true))
    check_retrieval(:clients, response, :client_id)
  end

  it "paginates client search using page_size" do
    first = live_api.clients.search(
      company_id: company_id,
      per_page: 1,
      fields: ["id"],
      order_by: "id",
      order_by_direction: "ASC",
    )
    skip "Test account needs at least two clients" unless first.next_page?
    sleep 0.3
    second = live_api.clients.search(
      company_id: company_id,
      per_page: 1,
      page: 2,
      fields: ["id"],
      order_by: "id",
      order_by_direction: "ASC",
    )
    check_collection(second)
    expect(second.items.first && second.items.first[:id] != first.items.first[:id]).to(be(true))
  end

  it "lists and retrieves records" do
    response = live_api.records.list(
      company_id: company_id,
      per_page: 1,
      start_date: ENV.fetch("YCLIENTS_START_DATE", Date.today.prev_month.iso8601),
      end_date: ENV.fetch("YCLIENTS_END_DATE", Date.today.iso8601),
    )
    check_collection(response)
    expect(response.meta.is_a?(Hash) && response.meta[:total_count].is_a?(Integer)).to(be(true))
    check_retrieval(:records, response, :record_id)
  end

  { services: :service_id, staff: :staff_id }.each do |resource, id_key|
    it "lists and retrieves #{resource} using the current company route" do
      response = live_api.public_send(resource).list(company_id: company_id)
      check_collection(response)
      check_retrieval(resource, response, id_key)
    end
  end

  it "retrieves permissions and accepts the documented group filter" do
    response = live_api.permissions.retrieve(company_id: company_id, groups: ["settings"])
    check_response(response)
    expect(response.data.is_a?(Hash)).to(be(true))
    expect(response.data.key?(:settings)).to(be(true))
  end

  it "authorizes when optional test account login and password are supplied" do
    keys = ["YCLIENTS_LOGIN", "YCLIENTS_PASSWORD"]
    configured = keys.all? { |key| !ENV.fetch(key, "").empty? }
    skip "Set YCLIENTS_LOGIN and YCLIENTS_PASSWORD for the auth contract" unless configured
    response = live_api.auth.authorize(login: ENV.fetch("YCLIENTS_LOGIN"), password: ENV.fetch("YCLIENTS_PASSWORD"))
    check_response(response)
    expect(response.user_token.is_a?(String) || response.data.key?(:uuid)).to(be(true))
  end
end
