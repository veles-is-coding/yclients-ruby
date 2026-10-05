# frozen_string_literal: true

module Yclients
  module Resources
    class Services < Base
      def list(company_id:, staff_id: nil, category_id: nil)
        response = transport.request(
          :get,
          "/company/#{id(company_id)}/services/",
          params: { staff_id: staff_id, category_id: category_id }.compact,
        )
        Page.new(response: response)
      end

      def retrieve(company_id:, service_id:)
        transport.request(:get, "/company/#{id(company_id)}/services/#{id(service_id)}")
      end
    end
  end
end
