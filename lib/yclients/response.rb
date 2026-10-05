# frozen_string_literal: true

module Yclients
  class Response
    attr_reader :payload, :status, :headers

    def initialize(payload:, status:, headers:)
      @payload = payload
      @status = status
      @headers = headers
    end

    def data
      envelope? ? payload[:data] : payload
    end

    def meta
      envelope? ? payload.fetch(:meta, {}) : {}
    end

    def inspect
      "#<#{self.class} status=#{status}>"
    end

    private

    def envelope?
      payload.is_a?(Hash) && (payload.key?(:data) || payload.key?(:success))
    end
  end
end
