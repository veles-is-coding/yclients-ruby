# frozen_string_literal: true

module Yclients
  class Page < Response
    attr_reader :page, :per_page

    def initialize(response:, page: 1, per_page: nil, use_total_count: true)
      super(payload: response.payload, status: response.status, headers: response.headers)
      raise ResponseError, "YCLIENTS collection data must be an array" unless data.is_a?(Array)

      @page = page
      @per_page = per_page
      @use_total_count = use_total_count
    end

    def items
      data
    end

    def next_page?
      return false if per_page.nil? || items.empty?

      total = meta[:total_count] if @use_total_count && meta.is_a?(Hash)
      return page * per_page < total.to_i if total.to_s.match?(/\A\d+\z/)

      items.length >= per_page
    end
  end
end
