# frozen_string_literal: true

module Yclients
  module Resources
    class Auth < Base
      class Result < Response
        def user_token
          data[:user_token] if data.is_a?(Hash)
        end
      end

      def authorize(login:, password:)
        response = transport.request(:post, "/auth", body: { login: login, password: password })
        Result.new(payload: response.payload, status: response.status, headers: response.headers)
      end
    end
  end
end
