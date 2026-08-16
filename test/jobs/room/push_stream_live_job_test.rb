require "test_helper"

class Room::PushStreamLiveJobTest < ActiveJob::TestCase
  test "pushes only to disconnected members involved in everything" do
    room = rooms(:designers)
    room.update_columns stream_enabled: true, stream_session_id: "session-1",
      stream_live_at: Time.current, stream_last_seen_at: Time.current, stream_title: "Town Hall"
    memberships(:jz_designers).connected

    Rails.configuration.x.web_push_pool.expects(:queue).with(
      { title: room.name, body: "Town Hall is live now", path: Rails.application.routes.url_helpers.room_path(room) },
      kind_of(ActiveRecord::Relation)
    )

    Room::PushStreamLiveJob.perform_now(room, "session-1")
  end

  test "does not push for an expired or replaced session" do
    room = rooms(:designers)
    room.update_columns stream_enabled: true, stream_session_id: "session-2", stream_last_seen_at: Time.current

    Rails.configuration.x.web_push_pool.expects(:queue).never
    Room::PushStreamLiveJob.perform_now(room, "session-1")
  end
end
