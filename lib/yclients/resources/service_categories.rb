# frozen_string_literal: true

module Yclients
  module Resources
    class ServiceCategories < Base
      def list(company_id:)
        Page.new(response: transport.request(:get, "/company/#{id(company_id)}/service_categories/"))
      end

      def retrieve(company_id:, category_id:)
        transport.request(:get, "/service_category/#{id(company_id)}/#{id(category_id)}")
      end
    end
  end
end
