# frozen_string_literal: true

require "faraday"
require "json"

module Yclients
  module Transport
    class Faraday
      ERROR_CLASSES = {
        400 => ValidationError,
        401 => AuthenticationError,
        403 => ForbiddenError,
        404 => NotFoundError,
        422 => ValidationError,
        429 => RateLimitError,
      }.freeze
      RETRY_STATUSES = [429, 502, 503, 504].freeze
      LOG_SEGMENTS = [
        "auth",
        "company",
        "companies",
        "clients",
        "client",
        "search",
        "records",
        "record",
        "services",
        "staff",
        "user",
        "permissions",
      ].freeze

      def initialize(configuration)
        @configuration = configuration
        @connection = build_connection
        # Build middleware before the transport is shared between threads.
        @connection.app
      end

      def request(method, path, params: {}, body: nil)
        path = validate_path(path)
        encoded_body = body.nil? ? nil : JSON.generate(Serialization.normalize(body))
        normalized_params = Serialization.normalize(params)
        retries = 0
        loop do
          begin
            response = perform(method, path, normalized_params, encoded_body, retries)
          rescue ::Faraday::TimeoutError, ::Faraday::ConnectionFailed
            raise unless retryable?(method, retries)

            backoff(retries)
            retries += 1
            next
          end
          return build_response(response, method, path) unless RETRY_STATUSES.include?(response.status) && retryable?(
            method, retries
          )

          backoff(retries)
          retries += 1
        end
      rescue ::Faraday::TimeoutError
        raise TimeoutError, "YCLIENTS request timed out", cause: nil
      rescue ::Faraday::ConnectionFailed, ::Faraday::SSLError
        raise ConnectionError, "YCLIENTS connection failed", cause: nil
      end

      def inspect
        "#<#{self.class}>"
      end

      private

      def perform(method, path, params, body, retries)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = @connection.run_request(method, "#{@configuration.base_url}#{path}", body, headers) do |req|
          req.params.update(params)
        end
      ensure
        log(method, path, response&.status, started, retries)
      end

      def retryable?(method, retries)
        [:get, :head].include?(method) && retries < 2
      end

      def backoff(retries)
        ceiling = [0.5 * (2**retries), 2.0].min
        sleep(ceiling * (0.5 + (rand * 0.5)))
      end

      def log(method, path, status, started, retries)
        return unless @configuration.logger

        safe_path = path.split("/").map do |segment|
          LOG_SEGMENTS.include?(segment) ? segment : ":redacted"
        end.drop(1).join("/")
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @configuration.logger.info("#{method.to_s.upcase} /#{safe_path} status=#{status || "none"} " \
          "duration=#{format("%.3f", duration)} retries=#{retries}")
      rescue StandardError
        # A logging failure must not change a completed request's outcome.
        nil
      end

      def build_connection
        ::Faraday.new do |conn|
          conn.options.timeout = @configuration.timeout
          conn.options.open_timeout = @configuration.open_timeout
          conn.adapter(:net_http)
        end
      end

      def headers
        authorization = "Bearer #{@configuration.partner_token}"
        authorization += ", User #{@configuration.user_token}" if @configuration.user_token
        {
          "Authorization" => authorization,
          "Accept" => "application/vnd.yclients.v2+json",
          "Content-Type" => "application/json",
        }
      end

      def validate_path(path)
        unless path.is_a?(String) && !path.empty? && !path.match?(/[%?#\\\s\x00-\x1f\x7f]/)
          raise ConfigurationError, "path must be an unescaped relative API path; pass query values via params"
        end

        uri = URI.parse(path)
        if uri.host || uri.scheme || path.start_with?("//") || path.split("/").intersect?([".", ".."])
          raise ConfigurationError, "path must stay within the configured API base URL"
        end

        path.start_with?("/") ? path : "/#{path}"
      rescue URI::InvalidURIError
        raise ConfigurationError, "invalid API path", cause: nil
      end

      def build_response(response, method, path)
        successful = (200..299).cover?(response.status)
        payload = parse(response.body, allow_invalid: !successful, empty: response.status == 204 || method == :head)
        if !successful || (payload.is_a?(Hash) && payload[:success] == false)
          klass = ERROR_CLASSES.fetch(response.status) { response.status >= 500 ? ServerError : ApiError }
          raise klass.new(
            status: response.status,
            method: method,
            path: path,
            response_body: response.body,
            response_headers: response.headers.to_h,
            details: payload.is_a?(Hash) ? payload[:meta] : nil,
          )
        end

        Response.new(payload: payload, status: response.status, headers: response.headers.to_h)
      end

      def parse(body, allow_invalid:, empty:)
        return if empty && (body.nil? || body.empty?)

        JSON.parse(body.to_s.b, symbolize_names: true)
      rescue JSON::ParserError, EncodingError
        return if allow_invalid

        raise ParseError, "YCLIENTS returned invalid JSON", cause: nil
      end
    end
  end
end
