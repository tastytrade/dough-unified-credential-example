require 'rubygems'
require 'pry'
require 'json'
require 'faraday'
require_relative 'hmac_utils'
require_relative 'utilities'

module DoughUnifiedCredential
  class Client
    attr_reader :client
    ROUTES = YAML::load_file("routes.yml")

    def initialize(options = {})
      build_client(options)
    end

    def routes
      routes = []
      ROUTES.each do |controller, actions|
        actions.each do |action, detail|
          routes << "#{action}_#{controller.gsub(/(s*)$/, '')}"
        end
      end
      routes
    end

    ROUTES.each do |controller, actions|
      actions.each do |action, detail|
        define_method "#{action}_#{controller.gsub(/(s*)$/, '')}" do |*args|
          perform(detail["method"].downcase.to_sym, detail["path"].concat('.json'), build_request_format(args.first || {}))
        end
      end
    end

    def perform(method, route, payload = {})
      @client.send(method, route, payload)
    end

    private

    def build_request_format(payload = {})
      # 1. add user node to user parameters
      params = {user: payload.permit(:email, :name, :nickname, :password, :password_confirmation, :current_password)}
      # 2. add client domain and hashify signature
      signatured_params = params.merge(client_name: trusted_domain[:domain_name])
      request_signature = HmacUtils.sign_message(signatured_params, trusted_domain[:api_token])
      # 3. add timestamp and signature to params
      signatured_params.merge(signature: request_signature,
                              timestamp: Time.now)
    end

    def build_client(options)
      @client = Faraday.new(:url => "http://localhost:#{options[:port]}") do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
    end

    def trusted_domain
      # note this must be created on DUC server and values copied in
      { api_token: "G3UrfZGRiWGDd4xHt7ZLdJNkEYSt2EKYjSrDxW0XGjy5OFFTdBAM6xYjpFpV2FNaxTPpmoIBdNMxJMXWnReDOg",
        shared_secret: "83F_H1XcW6nIW-UDvEbaTUPWp5q42IazNHpKZ67exoA",
        domain_name: "example_domain"
      }
    end
  end
end