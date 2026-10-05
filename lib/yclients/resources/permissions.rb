# frozen_string_literal: true

module Yclients
  module Resources
    class Permissions < Base
      def retrieve(company_id:, groups: nil)
        transport.request(:get, "/user/permissions/#{id(company_id)}", params: { group_permissions: groups }.compact)
      end
    end
  end
end
