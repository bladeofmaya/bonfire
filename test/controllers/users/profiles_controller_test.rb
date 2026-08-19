require "test_helper"

class Users::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get user_profile_url

    assert_response :success
    assert_select "nav[role='tablist'][aria-label='Profile settings']" do
      assert_select "button[role='tab'][aria-selected='true'][data-profile-tabs-name='profile']", text: "Profile"
      assert_select "button[role='tab'][data-profile-tabs-name]", count: 5
      assert_select "[data-lucide]", count: 5
    end
    assert_select "section[role='tabpanel'][data-profile-tabs-name]", count: 5
    assert_select "#profile-panel-appearance[hidden] select[data-theme-target='select']" do
      assert_select "option[value='system']", "Use system setting"
      assert_select "option[value='light']", "Light"
      assert_select "option[value='dark']", "Dark"
    end

    assert_select "form[action='#{session_path}'] button.btn[type='submit'][aria-label='Log out'][data-action='sessions#logout:prevent']" do
      assert_select "img[aria-hidden='true'][src*='logout']"
    end
  end

  test "shows and updates email notification preferences" do
    get user_profile_url

    assert_select "#profile-panel-notifications[hidden]" do
      assert_select ".profile-settings__heading .txt-negative[role='status']", text: /currently disabled/
      assert_select ".profile-settings__heading .txt-supporting", text: /Choose what Bonfire sends/
      assert_select ".txt-supporting", minimum: 4
      assert_select "input[name='user[email_notifications_enabled]'][type='checkbox'][disabled]"
      assert_select "input[name='user[email_mentions_enabled]'][type='checkbox'][checked][disabled]"
      assert_select "input[name='user[email_daily_summary_enabled]'][type='checkbox'][disabled]"
      assert_select "input[name='user[email_stream_live_enabled]'][type='checkbox'][disabled]"
      assert_select "input[name='user[email_new_user_signup_enabled]'][type='checkbox'][disabled]"
      assert_select "label", text: /New user signups Admin/ do
        assert_select ".profile-settings__admin-label", text: "Admin"
      end
      assert_select "select[name='user[email_digest_hour]'][disabled]"
      assert_select "select[name='user[email_time_zone]'][disabled]"
      assert_select "input[type='submit'][disabled]"
    end

    previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    begin
      put user_profile_url, params: { user: {
        email_notifications_enabled: "1", email_mentions_enabled: "0", email_daily_summary_enabled: "1",
        email_stream_live_enabled: "1", email_new_user_signup_enabled: "1",
        email_digest_hour: "18", email_time_zone: "Bern"
      } }
    ensure
      Rails.configuration.x.email_notifications.enabled = previous_enabled
    end

    assert_redirected_to user_profile_url
    user = users(:david).reload
    assert user.email_notifications_enabled?
    assert_not user.email_mentions_enabled?
    assert user.email_daily_summary_enabled?
    assert user.email_stream_live_enabled?
    assert user.email_new_user_signup_enabled?
    assert_equal 18, user.email_digest_hour
    assert_equal "Bern", user.email_time_zone
  end

  test "members cannot see or update new user signup notifications" do
    sign_in :jz
    previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    begin
      get user_profile_url
      assert_select "input[name='user[email_new_user_signup_enabled]']", count: 0

      put user_profile_url, params: { user: { email_new_user_signup_enabled: "1" } }
    ensure
      Rails.configuration.x.email_notifications.enabled = previous_enabled
    end

    assert_not users(:jz).reload.email_new_user_signup_enabled?
  end

  test "email preferences cannot be changed while delivery is globally disabled" do
    put user_profile_url, params: { user: {
      email_notifications_enabled: "1", email_daily_summary_enabled: "1", email_stream_live_enabled: "1"
    } }

    user = users(:david).reload
    assert_not user.email_notifications_enabled?
    assert_not user.email_daily_summary_enabled?
    assert_not user.email_stream_live_enabled?
  end

  test "conversation names truncate without displacing notification controls" do
    long_name = "Steel of Sky the third, lord of the lands between and protector of the realm"
    rooms(:watercooler).update! name: long_name

    get user_profile_url

    assert_select "#profile-panel-conversations[hidden] fieldset.settings-group.conversations-settings.min-width.full-width" do
      assert_select "legend.for-screen-reader", text: "Your conversations"
      assert_select "div.min-width.full-width menu.min-width.full-width"
      assert_select ".membership-item" do
        assert_select "a.flex-item-grow.min-width.overflow-ellipsis[title='#{long_name}']", text: long_name
        assert_select "span.flex-item-no-shrink turbo-frame button[role='checkbox']"
      end
    end
  end

  test "show handles a direct conversation hidden from the sidebar" do
    membership = memberships(:david_david_and_jason)
    membership.update!(involvement: :invisible)

    get user_profile_url

    assert_response :success
    assert_select "##{dom_id(membership.room, :involvement)}" do
      assert_select "input[name='involvement'][value='everything']", visible: false
      assert_select "[role='checkbox'][aria-labelledby='#{dom_id(membership.room, :involvement_label)}']"
      assert_select "##{dom_id(membership.room, :involvement_label)}",
        text: "Notifications are off and room invisible in sidebar"
    end
  end

  test "update" do
    put user_profile_url, params: { user: { name: "John Doe", bio: "Acrobat" } }

    assert_redirected_to user_profile_url
    assert_equal "John Doe", users(:david).reload.name
    assert_equal "Acrobat", users(:david).bio
    assert_equal "david@37signals.com", users(:david).email_address
  end

  test "updates are limited to the current user" do
    put user_profile_url(users(:jason)), params: { user: { name: "John Doe" } }

    assert_equal "Jason", users(:jason).reload.name
  end
end
