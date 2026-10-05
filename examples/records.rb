# frozen_string_literal: true

require "yclients"
require "date"

api = Yclients::Client.new(
  partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"),
  user_token: ENV.fetch("YCLIENTS_USER_TOKEN"),
)

# Replace 123 with a company ID from your application's settings.
api.records.each(
  company_id: 123,
  start_date: Date.new(2025, 1, 1),
  end_date: Date.today,
) do |record|
  puts record[:id]
end
