# frozen_string_literal: true

require_relative "version"
require_relative "errors"
require_relative "configuration"
require_relative "serialization"
require_relative "response"
require_relative "page"
require_relative "transport/faraday"
require_relative "resources/base"
require_relative "resources/paginated"
require_relative "resources/auth"
require_relative "resources/companies"
require_relative "resources/clients"
require_relative "resources/records"
require_relative "resources/services"
require_relative "resources/staff"
require_relative "resources/permissions"

module Yclients
  class Client
    attr_reader :configuration

    RESOURCES = {
      auth: Resources::Auth,
      companies: Resources::Companies,
      clients: Resources::Clients,
      records: Resources::Records,
      services: Resources::Services,
      staff: Resources::Staff,
      permissions: Resources::Permissions,
    }.freeze

    RESOURCES.each do |name, klass|
      define_method(name) { klass.new(@transport) }
    end

    def initialize(transport: Transport::Faraday.method(:new), **)
      @configuration = Configuration.new(**)
      @transport_factory = transport
      @transport = transport.call(configuration)
      freeze
    end

    def with_user_token(token)
      config = configuration.with_user_token(token)
      self.class.new(
        partner_token: config.partner_token,
        user_token: config.user_token,
        base_url: config.base_url,
        timeout: config.timeout,
        open_timeout: config.open_timeout,
        logger: config.logger,
        transport: @transport_factory,
      )
    end

    def inspect
      "#<#{self.class} credentials=[REDACTED]>"
    end
  end
end
