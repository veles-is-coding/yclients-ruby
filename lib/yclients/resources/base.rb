# frozen_string_literal: true

module Yclients
  module Resources
    class Base
      def initialize(transport)
        @transport = transport
        freeze
      end

      def inspect
        "#<#{self.class}>"
      end

      private

      attr_reader :transport

      def id(value)
        case value
        when Integer
          return value.to_s if value.positive?
        when String
          return value if value.match?(/\A[1-9]\d*\z/)
        end

        raise ConfigurationError, "resource identifiers must be positive integers or numeric strings"
      end

      def validate_pagination(page, per_page)
        unless page.is_a?(Integer) && page.positive?
          raise ConfigurationError, "page must be a positive integer"
        end

        unless per_page.is_a?(Integer) && per_page.positive?
          raise ConfigurationError, "per_page must be a positive integer"
        end
      end
    end
  end
end
