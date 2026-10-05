# frozen_string_literal: true

module Yclients
  module Resources
    class Staff < Base
      def list(company_id:)
        Page.new(response: transport.request(:get, "/company/#{id(company_id)}/staff/"))
      end

      def retrieve(company_id:, staff_id:)
        transport.request(:get, "/company/#{id(company_id)}/staff/#{id(staff_id)}")
      end
    end
  end
end
