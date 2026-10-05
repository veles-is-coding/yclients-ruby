# frozen_string_literal: true

module Yclients
  module Resources
    class Records < Base
      include Paginated

      def list(company_id:, start_date: nil, end_date: nil, staff_id: nil, client_id: nil, page: 1, per_page: 300)
        validate_pagination(page, per_page)
        params = {
          start_date: start_date,
          end_date: end_date,
          staff_id: staff_id,
          client_id: client_id,
          page: page,
          count: per_page,
        }.compact
        response = transport.request(:get, "/records/#{id(company_id)}", params: params)
        # The records reference describes total_count as a current-page count, not a reliable overall total.
        Page.new(response: response, page: page, per_page: per_page, use_total_count: false)
      end

      def retrieve(company_id:, record_id:)
        transport.request(:get, "/record/#{id(company_id)}/#{id(record_id)}")
      end
    end
  end
end
