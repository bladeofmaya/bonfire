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
      assert_select "button[role='tab'][data-profile-tabs-name]", count: 4
      assert_select "[data-lucide]", count: 4
    end
    assert_select "section[role='tabpanel'][data-profile-tabs-name]", count: 4
    assert_select "#profile-panel-appearance[hidden] select[data-theme-target='select']" do
      assert_select "option[value='system']", "Use system setting"
      assert_select "option[value='light']", "Light"
      assert_select "option[value='dark']", "Dark"
    end

    assert_select "form[action='#{session_path}'] button.btn[type='submit'][aria-label='Log out'][data-action='sessions#logout:prevent']" do
      assert_select "img[aria-hidden='true'][src*='logout']"
    end
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
