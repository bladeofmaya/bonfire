require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  test "delivery test goes to the administrator and links to notification settings" do
    administrator = users(:david)
    email = NotificationMailer.with(user: administrator).delivery_test

    assert_equal [ administrator.email_address ], email.to
    assert_equal "Bonfire email delivery test", email.subject
    assert_includes email.html_part.body.to_s, "Bonfire email delivery works"
    assert_includes email.html_part.body.to_s, "#notifications"
    assert_includes email.text_part.body.to_s, "#notifications"
  end
end
