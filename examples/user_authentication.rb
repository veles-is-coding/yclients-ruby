# frozen_string_literal: true

require "yclients"

base = Yclients::Client.new(partner_token: ENV.fetch("YCLIENTS_PARTNER_TOKEN"))
user_api = base.with_user_token(ENV.fetch("YCLIENTS_USER_TOKEN"))

user_api.clients.each(company_id: ENV.fetch("YCLIENTS_COMPANY_ID"), fields: ["id"]) do |client|
  puts client[:id]
end
