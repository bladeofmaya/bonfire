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

  test "stream live includes the rich description in HTML and plain text" do
    user = users(:david)
    room = rooms(:watercooler)
    room.update!(stream_title: "Friday Night", stream_description: <<~HTML)
      <h2>Tonight’s plan</h2>
      <p>Community updates and <strong>live questions</strong>.</p>
    HTML

    email = NotificationMailer.with(user:, room:).stream_live

    assert_includes email.html_part.body.to_s, "Tonight’s plan"
    assert_includes email.html_part.body.to_s, "<strong>live questions</strong>"
    assert_includes email.text_part.body.to_s, "Tonight’s plan"
    assert_includes email.text_part.body.to_s, "Community updates and live questions."
  end
end
