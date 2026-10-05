# frozen_string_literal: true

module Yclients
  module Resources
    module Paginated
      def each(**options, &block)
        return enum_for(:each, **options) unless block_given?

        each_page(**options) do |page|
          page.items.each(&block)
        end

        self
      end

      def each_page(page: 1, **options)
        return enum_for(:each_page, page: page, **options) unless block_given?

        loop do
          result = fetch_page(page: page, **options)
          yield result
          break unless result.next_page?

          page += 1
        end

        self
      end

      private

      def fetch_page(**options)
        list(**options)
      end
    end
  end
end
