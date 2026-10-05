# frozen_string_literal: true

require "uri"

module Yclients
  class Configuration
    attr_reader :partner_token, :user_token, :base_url, :timeout, :open_timeout, :logger

    def initialize(partner_token:, user_token: nil, base_url: "https://api.yclients.com/api/v1",
      timeout: 10, open_timeout: 5, logger: nil)
      @partner_token = token(partner_token)
      @user_token = user_token.nil? ? nil : token(user_token)
      @base_url = validate_url(base_url)
      @timeout = positive_timeout(timeout)
      @open_timeout = positive_timeout(open_timeout)
      raise ConfigurationError, "logger must respond to info" if logger && !logger.respond_to?(:info)

      @logger = logger
      freeze
    end

    def with_user_token(value)
      self.class.new(
        partner_token: partner_token,
        user_token: value,
        base_url: base_url,
        timeout: timeout,
        open_timeout: open_timeout,
        logger: logger,
      )
    end

    def inspect
      "#<#{self.class} credentials=[REDACTED]>"
    end

    private

    def token(value)
      unless value.is_a?(String) && value.match?(/\A[^\s,\x00-\x1f\x7f]+\z/)
        raise ConfigurationError, "tokens must be nonempty strings without whitespace or commas"
      end

      value.dup.freeze
    end

    def positive_timeout(value)
      unless value.is_a?(Numeric) && value.real? && value.finite? && value.positive?
        raise ConfigurationError, "timeouts must be positive finite numbers"
      end

      value
    end

    def validate_url(value)
      uri = URI.parse(value) if value.is_a?(String)
      unless uri.is_a?(URI::HTTP) && uri.host && !uri.userinfo && !uri.query && !uri.fragment
        raise ConfigurationError, "base_url must be an HTTP(S) URL without credentials, query or fragment"
      end

      value.sub(%r{/+\z}, "").freeze
    rescue URI::InvalidURIError
      raise ConfigurationError, "invalid base_url", cause: nil
    end
  end
end
