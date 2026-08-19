require "test_helper"

class EmailNotifications::NewUserSignupJobTest < ActiveSupport::TestCase
  setup do
    @previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    ActionMailer::Base.deliveries.clear

    @administrator = users(:david)
    @administrator.update!(email_notifications_enabled: true, email_new_user_signup_enabled: true)
    @new_user = users(:kevin)
  end

  teardown do
    Rails.configuration.x.email_notifications.enabled = @previous_enabled
  end

  test "emails opted-in administrators once at their registered address" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmailNotifications::NewUserSignupJob.perform_now(@new_user)
      EmailNotifications::NewUserSignupJob.perform_now(@new_user)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ @administrator.email_address ], email.to
    assert_includes email.subject, @new_user.name
    url_options = Rails.application.config.action_mailer.default_url_options
    assert_includes email.html_part.body.to_s,
      Rails.application.routes.url_helpers.user_url(@new_user, **url_options)
    assert_includes email.html_part.body.to_s, "#notifications"
  end

  test "does not email members or administrators who have not opted in" do
    @administrator.update!(email_new_user_signup_enabled: false)
    users(:jz).update!(email_notifications_enabled: true, email_new_user_signup_enabled: true)

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      EmailNotifications::NewUserSignupJob.perform_now(@new_user)
    end
  end
end
