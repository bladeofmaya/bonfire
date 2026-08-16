require "test_helper"

class Room::PushStreamLiveJobTest < ActiveJob::TestCase
  test "pushes to every active visible member regardless of connection or involvement" do
    room = rooms(:designers)
    room.update_columns stream_enabled: true, stream_session_id: "session-1",
      stream_live_at: Time.current, stream_last_seen_at: Time.current, stream_title: "Town Hall"
    memberships(:jz_designers).connected
    memberships(:kevin_designers).update!(involvement: :invisible)

    queued_subscription_ids = nil
    Rails.configuration.x.web_push_pool.expects(:queue).once.with do |payload, subscriptions|
      assert_equal({
        title: room.name, body: "Town Hall is live now", path: Rails.application.routes.url_helpers.room_path(room)
      }, payload)
      queued_subscription_ids = subscriptions.ids
      true
    end

    Room::PushStreamLiveJob.perform_now(room, "session-1")

    assert_equal [
      push_subscriptions(:david_chrome).id,
      push_subscriptions(:jason_chrome).id,
      push_subscriptions(:jz_chrome).id
    ].sort, queued_subscription_ids.sort
  end

  test "does not push for an expired or replaced session" do
    room = rooms(:designers)
    room.update_columns stream_enabled: true, stream_session_id: "session-2", stream_last_seen_at: Time.current

    Rails.configuration.x.web_push_pool.expects(:queue).never
    Room::PushStreamLiveJob.perform_now(room, "session-1")
  end
end
