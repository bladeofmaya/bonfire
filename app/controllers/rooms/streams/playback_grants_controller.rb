class Rooms::Streams::PlaybackGrantsController < ApplicationController
  include RoomScoped

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  before_action :ensure_active_human
  before_action :ensure_stream_available

  def create
    grant = Streaming::PlaybackGrant.new(room: @room, user: Current.user)

    response.set_header "Cache-Control", "no-store"
    render json: {
      token: grant.token,
      expires_at: grant.expires_at.iso8601,
      player_origin: @room.stream_player_origin,
      player_url: @room.stream_player_url,
      stream_path: @room.stream_path
    }
  rescue Streaming::Configuration::Error
    head :service_unavailable
  end

  private
    def request_authentication
      head :unauthorized
    end

    def ensure_active_human
      head :forbidden unless Current.user&.active? && !Current.user.bot?
    end

    def ensure_stream_available
      if !@room.stream_enabled?
        head :not_found
      elsif !@room.stream_configured? || !Streaming::Configuration.configured?
        head :unprocessable_entity
      end
    end
end
