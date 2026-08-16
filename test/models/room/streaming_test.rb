require "test_helper"

class Room::StreamingTest < ActiveSupport::TestCase
  test "liveness requires an enabled stream with a fresh heartbeat" do
    room = rooms(:watercooler)
    room.assign_attributes stream_enabled: true, stream_session_id: "session-1", stream_last_seen_at: Time.current
    assert room.stream_live?

    room.stream_last_seen_at = Room::Streaming::HEARTBEAT_TTL.ago - 1.second
    assert_not room.stream_live?

    room.stream_last_seen_at = Time.current
    room.stream_enabled = false
    assert_not room.stream_live?
  end

  test "a stop from an old publisher session cannot stop the current session" do
    room = configured_room
    room.update! stream_session_id: "new-session", stream_live_at: Time.current, stream_last_seen_at: Time.current

    assert_not room.apply_stream_event!(type: "stream.stopped", session_id: "old-session", occurred_at: Time.current)
    assert_equal "new-session", room.reload.stream_session_id
  end

  test "a started event enqueues only one notification for its session" do
    room = configured_room

    assert_enqueued_jobs 1, only: Room::PushStreamLiveJob do
      room.apply_stream_event!(type: "stream.started", session_id: "session-1", occurred_at: Time.current)
      room.apply_stream_event!(type: "stream.started", session_id: "session-1", occurred_at: Time.current)
    end
  end

  private
    def configured_room
      configure_streaming
      rooms(:watercooler).tap do |room|
        room.update! stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live"
      end
    end
end
