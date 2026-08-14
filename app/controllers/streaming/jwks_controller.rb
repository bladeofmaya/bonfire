class Streaming::JwksController < ApplicationController
  allow_unauthenticated_access

  def show
    expires_in 5.minutes, public: true
    render json: Streaming::Jwks.as_json
  rescue Streaming::Configuration::Error
    head :service_unavailable
  end
end
