require "test_helper"

class EmailNotifications::StreamLiveJobTest < ActiveSupport::TestCase
  setup do
    @previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    ActionMailer::Base.deliveries.clear

    @room = rooms(:designers)
    @room.update_columns stream_enabled: true, stream_session_id: "session-live-email",
      stream_live_at: Time.current, stream_last_seen_at: Time.current, stream_title: "Town Hall"
    @connected_user = users(:jz)
    @connected_user.update!(email_notifications_enabled: true, email_stream_live_enabled: true)
    memberships(:jz_designers).connected
  end

  teardown do
    Rails.configuration.x.email_notifications.enabled = @previous_enabled
  end

  test "emails an opted-in member even while connected and only once per session" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmailNotifications::StreamLiveJob.perform_now(@room, "session-live-email")
      EmailNotifications::StreamLiveJob.perform_now(@room, "session-live-email")
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @connected_user.email_address ], email.to
    assert_equal "Town Hall is live now", email.subject
    assert_includes email.html_part.body.to_s,
      Rails.application.routes.url_helpers.room_url(@room, **Rails.application.config.action_mailer.default_url_options)
    assert_includes email.html_part.body.to_s, "#notifications"
  end

  test "excludes invisible members and users who did not opt in" do
    invisible_user = users(:kevin)
    invisible_user.update!(email_notifications_enabled: true, email_stream_live_enabled: true)
    memberships(:kevin_designers).update!(involvement: :invisible)
    @connected_user.update!(email_stream_live_enabled: false)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotifications::StreamLiveJob.perform_now(@room, "session-live-email")
    end
  end

  test "does not email for an expired or replaced stream session" do
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotifications::StreamLiveJob.perform_now(@room, "different-session")
    end
  end
end
