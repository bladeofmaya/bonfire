require "application_system_test_case"

class ProfileLayoutTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    sign_in "david@37signals.com"
  end

  test "long conversation names truncate inside the profile panel" do
    long_name = "Steel of Sky the third, lord of the lands between and protector of the realm"
    rooms(:watercooler).update! name: long_name
    page.current_window.resize_to(600, 900)

    visit user_profile_path
    click_on "Conversations"

    link = find(".membership-item a[title='#{long_name}']")
    fieldset = find("fieldset.conversations-settings")
    tabs = find(".profile-settings__tabs")

    assert_operator width_of(link, :scrollWidth), :>, width_of(link, :clientWidth)
    assert_operator width_of(fieldset, :scrollWidth), :<=, width_of(fieldset, :clientWidth)
    assert_equal "row", page.evaluate_script("getComputedStyle(arguments[0]).flexDirection", tabs)
  end

  test "profile settings switch accessible tabs without growing one long page" do
    visit user_profile_path

    assert_selector "[role='tab'][aria-selected='true']", text: "Profile"
    assert_selector "#profile-panel-profile:not([hidden])"
    assert_selector "#profile-panel-appearance[hidden]", visible: false
    assert_selector "i[data-lucide]", count: 0
    assert_selector ".profile-settings__tab svg", count: 4

    click_on "Devices"

    assert_selector "[role='tab'][aria-selected='true']", text: "Devices"
    assert_selector "#profile-panel-devices:not([hidden])", text: "sign in on another device"
    assert_selector "#profile-panel-profile[hidden]", visible: false
    assert_equal "devices", URI.parse(current_url).fragment
  end

  test "arrow keys move focus and selection between tabs" do
    visit user_profile_path

    find("[role='tab']", text: "Profile").send_keys(:arrow_right)

    assert_selector "[role='tab'][aria-selected='true']", text: "Appearance"
    assert_selector "#profile-panel-appearance:not([hidden])"
    assert_equal "Appearance", page.evaluate_script("document.activeElement.textContent.trim()")
  end

  private
    def width_of(element, property)
      page.evaluate_script("arguments[0].#{property}", element)
    end
end
