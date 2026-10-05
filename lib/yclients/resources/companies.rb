# frozen_string_literal: true

module Yclients
  module Resources
    class Companies < Base
      include Paginated

      def list(page: 1, per_page: 100, **filters)
        validate_pagination(page, per_page)
        response = transport.request(:get, "/companies", params: filters.compact.merge(page: page, count: per_page))
        Page.new(response: response, page: page, per_page: per_page)
      end

      def retrieve(company_id:)
        transport.request(:get, "/company/#{id(company_id)}/")
      end
    end
  end
end
