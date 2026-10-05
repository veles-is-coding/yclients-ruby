# frozen_string_literal: true

require "date"
require "time"

module Yclients
  module Serialization
    class << self
      def normalize(value)
        case value
        when DateTime, Time, Date then value.iso8601
        when Hash then value.transform_values { |item| normalize(item) }
        when Array then value.map { |item| normalize(item) }
        else value
        end
      end
    end
  end
end
