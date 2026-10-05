# frozen_string_literal: true

module Yclients
  module Resources
    class Clients < Base
      include Paginated

      def search(company_id:, filters: {}, page: 1, per_page: 100, **options)
        validate_pagination(page, per_page)
        raise ConfigurationError, "client search per_page cannot exceed 200" if per_page > 200

        filters = [] if filters == {}
        raise ConfigurationError, "filters must be an array of YCLIENTS filter objects" unless filters.is_a?(Array)

        body = options.merge(page: page, page_size: per_page, filters: filters)
        response = transport.request(:post, "/company/#{id(company_id)}/clients/search", body: body)
        Page.new(response: response, page: page, per_page: per_page)
      end

      def retrieve(company_id:, client_id:)
        transport.request(:get, "/client/#{id(company_id)}/#{id(client_id)}")
      end

      private

      def fetch_page(**options)
        search(**options)
      end
    end
  end
end
