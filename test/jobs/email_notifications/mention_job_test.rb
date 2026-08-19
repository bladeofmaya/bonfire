require "test_helper"

class EmailNotifications::MentionJobTest < ActiveSupport::TestCase
  setup do
    @previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    ActionMailer::Base.deliveries.clear

    @user = users(:david)
    @user.update!(email_notifications_enabled: true, email_mentions_enabled: true)
    memberships(:david_designers).update!(connections: 0, connected_at: nil, involvement: :mentions)
  end

  teardown do
    Rails.configuration.x.email_notifications.enabled = @previous_enabled
  end

  test "delivers one email for an offline mention and links to settings" do
    message = rooms(:designers).messages.create!(
      creator: users(:jason), client_message_id: "email-mention",
      body: "Hello #{mention_attachment_for(:david)}"
    )

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmailNotifications::MentionJob.perform_now(message)
      EmailNotifications::MentionJob.perform_now(message)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_address ], email.to
    url_options = Rails.application.config.action_mailer.default_url_options
    host = url_options.fetch(:host)
    protocol = url_options.fetch(:protocol)
    routes = Rails.application.routes.url_helpers
    assert_includes email.html_part.body.to_s, routes.room_at_message_url(message.room, message, host:, protocol:)
    assert_includes email.html_part.body.to_s, "#{routes.user_profile_url(host:, protocol:)}#notifications"
    assert_includes email.text_part.body.to_s, "#notifications"
  end

  test "rechecks connection and preferences at delivery time" do
    message = rooms(:designers).messages.create!(
      creator: users(:jason), client_message_id: "email-suppressed",
      body: "Hello #{mention_attachment_for(:david)}"
    )
    memberships(:david_designers).update!(connections: 1, connected_at: Time.current)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotifications::MentionJob.perform_now(message)
    end

    memberships(:david_designers).update!(connections: 0, connected_at: nil)
    @user.update!(email_notifications_enabled: false)
    EmailNotifications::MentionJob.perform_now(message)
    assert_empty ActionMailer::Base.deliveries
  end

  test "direct conversations notify recipients without requiring an explicit mention" do
    message = rooms(:david_and_jason).messages.create!(
      creator: users(:jason), client_message_id: "direct-email", body: "Are you around?"
    )

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmailNotifications::MentionJob.perform_now(message)
    end
  end
end
