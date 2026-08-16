class Streaming::EventsController < ActionController::Base
  MAX_CLOCK_SKEW = 2.minutes
  EVENT_TYPES = %w[ stream.started stream.heartbeat stream.stopped ].freeze

  protect_from_forgery with: :null_session
  before_action :authenticate_event!

  def create
    event = JSON.parse(request.raw_post)
    validate_event!(event)

    Streaming::Event.transaction do
      Streaming::Event.create!(event_id: event.fetch("event_id"))
      room = Room.where(stream_enabled: true, stream_path: event.fetch("stream_path")).sole
      room.apply_stream_event!(
        type: event.fetch("type"), session_id: event.fetch("session_id"),
        occurred_at: Time.iso8601(event.fetch("occurred_at"))
      )
    end
    Streaming::Event.where(created_at: ...1.day.ago).delete_all

    head :no_content
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::SoleRecordExceeded
    head :conflict
  rescue JSON::ParserError, KeyError, ArgumentError
    head :unprocessable_entity
  end

  private
    def authenticate_event!
      timestamp = Integer(request.headers["X-Bonfire-Timestamp"], exception: false)
      signature = request.headers["X-Bonfire-Signature"].to_s
      secret = Streaming::Configuration.event_secret

      valid_time = timestamp && (Time.current.to_i - timestamp).abs <= MAX_CLOCK_SKEW
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, "#{timestamp}.#{request.raw_post}")
      valid_signature = signature.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(signature, expected)

      head :unauthorized unless secret.present? && valid_time && valid_signature
    end

    def validate_event!(event)
      raise ArgumentError unless event["version"] == 1 && EVENT_TYPES.include?(event["type"])
      raise ArgumentError unless event.values_at("event_id", "stream_path", "session_id", "occurred_at").all?(&:present?)

      occurred_at = Time.iso8601(event.fetch("occurred_at"))
      raise ArgumentError if (Time.current - occurred_at).abs > MAX_CLOCK_SKEW
    end
end
