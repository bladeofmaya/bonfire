require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "edit" do
    get edit_account_url
    assert_response :ok
    assert_select "nav[role='tablist'][aria-label='Account settings']" do
      assert_select "button[role='tab'][data-profile-tabs-name]", count: 4
      assert_select "button[aria-selected='true'][data-profile-tabs-name='general']", text: "General"
      assert_select "[data-lucide]", minimum: 4
    end
    assert_select "#account-panel-general:not([hidden])"
    assert_select "#account-panel-members[hidden] turbo-frame#account_users"
    assert_select "#account-panel-emotes[hidden] form[action='#{account_custom_emotes_path}']"
    assert_select "#account-panel-privacy[hidden] form.readme-editor" do
      assert_select "trix-editor#account_readme.input"
    end
  end

  test "edit groups administrators separately from members with a divider" do
    get edit_account_url

    assert_response :ok

    # Verify the divider exists between administrator and member sections
    assert_select "turbo-frame#account_users hr.separator.full-width"

    # Verify administrators appear before the divider and members appear after
    # by checking the order of user names in the response body
    administrators = users(:david, :jason).map(&:name)
    members = users(:jz, :kevin).map(&:name)

    response_body = response.body

    # Find positions of divider and user names
    divider_position = response_body.index('hr class="separator full-width"')
    assert divider_position, "Divider should exist in the response"

    administrators.each do |name|
      name_position = response_body.index("<strong>#{name}</strong>")
      assert name_position, "Administrator #{name} should appear in the response"
      assert name_position < divider_position, "Administrator #{name} should appear before the divider"
    end

    members.each do |name|
      name_position = response_body.index("<strong>#{name}</strong>")
      assert name_position, "Member #{name} should appear in the response"
      assert name_position > divider_position, "Member #{name} should appear after the divider"
    end
  end

  test "edit can select the emotes tab after a form redirect" do
    get edit_account_url(tab: "emotes")

    assert_select "[data-profile-tabs-default-tab-value='emotes']"
  end

  test "update" do
    assert users(:david).administrator?

    put account_url, params: { account: { name: "Different" } }

    assert_redirected_to edit_account_url
    assert_equal accounts(:signal).name, "Different"
  end

  test "administrator publishes and clears README" do
    account = accounts(:signal)

    put account_url, params: { account: { readme: "We use your email to operate this community." } }

    assert_redirected_to edit_account_url
    assert_equal "We use your email to operate this community.", account.reload.readme.to_plain_text
    assert_equal 1, account.readme_version

    put account_url, params: { account: { readme: "" } }

    assert_not account.reload.readme?
    assert_equal 2, account.readme_version
  end

  test "non-admins cannot update" do
    sign_in :kevin
    assert users(:kevin).member?

    put account_url, params: { account: { name: "Different" } }
    assert_response :forbidden
  end

  test "non-admins cannot publish README" do
    sign_in :kevin

    put account_url, params: { account: { readme: "Trust me." } }

    assert_response :forbidden
    assert_not accounts(:signal).reload.readme?
  end

  test "non-admins cannot see join links in account settings" do
    sign_in :kevin

    get edit_account_url

    assert_response :ok
    assert_select "#invite_url", count: 0
  end
end
