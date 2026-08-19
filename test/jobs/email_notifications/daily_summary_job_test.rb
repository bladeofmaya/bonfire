require "test_helper"

class EmailNotifications::DailySummaryJobTest < ActiveSupport::TestCase
  setup do
    @previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    ActionMailer::Base.deliveries.clear
    @user = users(:david)
    @user.update!(email_notifications_enabled: true, email_daily_summary_enabled: true, email_time_zone: "UTC")
  end

  teardown do
    Rails.configuration.x.email_notifications.enabled = @previous_enabled
  end

  test "delivers an idempotent summary of accessible unread messages" do
    period_on = Date.yesterday
    message = rooms(:designers).messages.create!(creator: users(:jason), body: "Yesterday's update", client_message_id: "daily-email")
    message.update_column(:created_at, period_on.noon)
    6.times do |index|
      additional = rooms(:designers).messages.create!(
        creator: users(:jason), body: "Later update #{index + 1}", client_message_id: "daily-email-#{index + 1}"
      )
      additional.update_column(:created_at, period_on.noon + (index + 1).minutes)
    end
    memberships(:david_designers).update!(unread_at: period_on.noon, unread_count: 1)

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmailNotifications::DailySummaryJob.perform_now(@user, period_on)
      EmailNotifications::DailySummaryJob.perform_now(@user, period_on)
    end

    email = ActionMailer::Base.deliveries.last
    assert_not_includes email.html_part.body.to_s, "Yesterday&#39;s update"
    assert_includes email.html_part.body.to_s, "Later update 6"
    assert_includes email.html_part.body.to_s, "Open channel with 7 new messages"
    assert_includes email.html_part.body.to_s, "#notifications"
    assert_includes email.text_part.body.to_s, "Open channel with 7 new messages"
    assert_includes email.text_part.body.to_s, "Change notification settings"
  end

  test "excludes stream channels" do
    period_on = Date.yesterday
    room = rooms(:designers)
    room.update_columns(stream_enabled: true)
    message = room.messages.create!(creator: users(:jason), body: "Noisy stream chat", client_message_id: "stream-summary")
    message.update_column(:created_at, period_on.noon)
    memberships(:david_designers).update!(unread_at: period_on.noon, unread_count: 1)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotifications::DailySummaryJob.perform_now(@user, period_on)
    end
  end

  test "hourly dispatcher respects each user's local hour" do
    @user.update!(email_digest_hour: 9, email_time_zone: "UTC")

    assert_enqueued_with(job: EmailNotifications::DailySummaryJob, args: [ @user, Date.new(2026, 8, 18) ]) do
      EmailNotifications::DailySummaryDispatchJob.perform_now(Time.utc(2026, 8, 19, 9))
    end
  end
end
