require "test_helper"

class Streaming::EventsControllerTest < ActionDispatch::IntegrationTest
  SECRET = "event-secret-for-tests"

  setup do
    configure_streaming
    Streaming::Configuration.stubs(event_secret: SECRET)
    @room = rooms(:watercooler)
    @room.update! stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live"
  end

  test "accepts signed lifecycle events and is idempotent" do
    assert_enqueued_jobs 1, only: Room::PushStreamLiveJob do
      post_event "stream.started", event_id: "start-1"
      assert_response :no_content
      assert_equal "session-1", @room.reload.stream_session_id

      post_event "stream.started", event_id: "start-1"
      assert_response :no_content
    end
  end

  test "rejects an invalid signature without changing state" do
    post streaming_events_url, params: event_body("stream.started", event_id: "start-1"),
      headers: event_headers.merge("X-Bonfire-Signature" => "invalid")

    assert_response :unauthorized
    assert_nil @room.reload.stream_session_id
  end

  test "ignores a delayed stop for an older session" do
    post_event "stream.started", event_id: "start-1"
    post_event "stream.started", event_id: "start-2", session_id: "session-2"
    post_event "stream.stopped", event_id: "stop-1", session_id: "session-1"

    assert_response :no_content
    assert_equal "session-2", @room.reload.stream_session_id
  end

  test "rejects stale events" do
    post_event "stream.started", event_id: "start-1", occurred_at: 5.minutes.ago

    assert_response :unprocessable_entity
    assert_nil @room.reload.stream_session_id
  end

  private
    def post_event(type, event_id:, session_id: "session-1", occurred_at: Time.current)
      body = event_body(type, event_id:, session_id:, occurred_at:)
      post streaming_events_url, params: body, headers: event_headers(body)
    end

    def event_body(type, event_id:, session_id: "session-1", occurred_at: Time.current)
      JSON.generate version: 1, event_id:, type:, stream_path: "live", session_id:, occurred_at: occurred_at.iso8601(3)
    end

    def event_headers(body = event_body("stream.started", event_id: "start-1"))
      timestamp = Time.current.to_i
      signature = OpenSSL::HMAC.hexdigest("SHA256", SECRET, "#{timestamp}.#{body}")
      { "CONTENT_TYPE" => "application/json", "X-Bonfire-Timestamp" => timestamp.to_s, "X-Bonfire-Signature" => signature }
    end
end
