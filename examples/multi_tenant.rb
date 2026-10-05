# frozen_string_literal: true

require "yclients"

# In an application, load these settings from tenants the current user can access.
# Replace the sample company IDs with branches belonging to each tenant.
tenants = [
  {
    id: "tenant_a",
    user_token: ENV.fetch("YCLIENTS_TENANT_A_USER_TOKEN"),
    company_ids: [123, 456],
  },
  {
    id: "tenant_b",
    user_token: ENV.fetch("YCLIENTS_TENANT_B_USER_TOKEN"),
    company_ids: [789],
  },
]

base = Yclients::Client.new(partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"))

tenants.each do |tenant|
  api = base.with_user_token(tenant.fetch(:user_token))

  tenant.fetch(:company_ids).each do |company_id|
    api.records.each(company_id: company_id) do |record|
      puts "#{tenant.fetch(:id)}: company #{company_id}, record #{record.fetch(:id)}"
    end
  end
end
