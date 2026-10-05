# frozen_string_literal: true

require "yclients"
require "date"

api = Yclients::Client.new(
  partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"),
  user_token: ENV.fetch("YCLIENTS_USER_TOKEN"),
)

api.records.each(
  company_id: ENV.fetch("YCLIENTS_COMPANY_ID"),
  start_date: Date.new(2025, 1, 1),
  end_date: Date.today,
) do |record|
  puts record[:id]
end
