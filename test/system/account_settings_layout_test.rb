require "application_system_test_case"

class AccountSettingsLayoutTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    sign_in "david@37signals.com"
    visit edit_account_path
  end

  test "switches between general and member settings" do
    assert_selector "[role='tab'][aria-selected='true']", text: "General"
    assert_selector "#account-panel-general:not([hidden])"
    assert_selector "#account-panel-members[hidden]", visible: false
    assert_selector "i[data-lucide]", count: 0
    assert_selector ".profile-settings__tab svg", count: 3

    click_on "Members"

    assert_selector "[role='tab'][aria-selected='true']", text: "Members"
    assert_selector "#account-panel-members:not([hidden])", text: "Share to invite more people"
    assert_selector "#account-panel-general[hidden]", visible: false
    assert_equal "members", URI.parse(current_url).fragment
  end

  test "previews and publishes README" do
    click_on "README"

    assert_selector "#account-panel-privacy:not([hidden])"
    assert_selector ".readme-editor trix-toolbar", visible: true
    fill_in_rich_text_area "account_readme", with: "We use your email to operate this community."
    click_on "Publish README"

    assert_current_path edit_account_path
    assert_equal "We use your email to operate this community.", accounts(:signal).reload.readme.to_plain_text
  end

  test "arrow keys switch account tabs" do
    find("[role='tab']", text: "General").send_keys(:arrow_right)

    assert_selector "[role='tab'][aria-selected='true']", text: "Members"
    assert_equal "Members", page.evaluate_script("document.activeElement.textContent.trim()")
  end
end
