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
    assert_selector ".profile-settings__tab svg", count: 5

    click_on "Members"

    assert_selector "[role='tab'][aria-selected='true']", text: "Members"
    assert_selector "#account-panel-members:not([hidden])", text: "Share to invite more people"
    assert_selector "#account-panel-general[hidden]", visible: false
    assert_equal "members", URI.parse(current_url).fragment
  end

  test "mobile navigation fits without horizontal scrolling" do
    page.current_window.resize_to(390, 700)
    visit edit_account_path
    click_on "README"

    tabs = find(".profile-settings__tabs")
    assert_equal "grid", page.evaluate_script("getComputedStyle(arguments[0]).display", tabs)
    assert_operator page.evaluate_script("arguments[0].scrollWidth", tabs), :<=,
      page.evaluate_script("arguments[0].clientWidth", tabs)
    assert_operator page.evaluate_script("arguments[0].scrollHeight", tabs), :<=,
      page.evaluate_script("arguments[0].clientHeight", tabs)
    assert_selector ".profile-settings__tab svg", count: 5

    tabs_bottom, last_tab_bottom, content_top = page.evaluate_script <<~JS
      (() => {
        const tabs = document.querySelector(".profile-settings__tabs").getBoundingClientRect()
        const items = Array.from(document.querySelectorAll(".profile-settings__tab"))
        const lowestItem = Math.max(...items.map(item => item.getBoundingClientRect().bottom))
        const content = document.querySelector(".profile-settings__content").getBoundingClientRect()
        return [tabs.bottom, lowestItem, content.top]
      })()
    JS
    assert_operator last_tab_bottom, :<=, tabs_bottom
    assert_operator content_top, :>=, tabs_bottom
  end

  test "shows mailer status, setup guide, and opted-in users" do
    users(:jz).update!(email_notifications_enabled: true)
    visit edit_account_path
    click_on "Notifications"

    assert_selector "#account-panel-notifications:not([hidden])", text: "Email delivery is disabled"
    assert_text "EMAIL_NOTIFICATIONS_ENABLED=true"

    find(".email-notifications-admin__users-trigger").click

    assert_selector ".email-notifications-admin__users-menu", text: users(:jz).name
    assert_selector ".email-notifications-admin__users-menu a[href='#{user_path(users(:jz))}']"
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
