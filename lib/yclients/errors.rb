# frozen_string_literal: true

module Yclients
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransportError < Error; end
  class ConnectionError < TransportError; end
  class TimeoutError < TransportError; end
  class ResponseError < Error; end
  class ParseError < ResponseError; end

  class ApiError < Error
    attr_reader :status, :method, :path, :response_body, :response_headers, :details

    def initialize(status:, method:, path:, response_body:, response_headers:, details: nil)
      @status = status
      @method = method
      @path = path
      @response_body = response_body
      @response_headers = response_headers
      @details = details
      super("YCLIENTS request failed (HTTP #{status})")
    end
  end

  class AuthenticationError < ApiError; end
  class ForbiddenError < ApiError; end
  class NotFoundError < ApiError; end
  class ValidationError < ApiError; end
  class RateLimitError < ApiError; end
  class ServerError < ApiError; end
end
