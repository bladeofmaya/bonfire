require "application_system_test_case"

class ServerContextMenuTest < ApplicationSystemTestCase
  test "channel rail continues growing on large desktops" do
    page.current_window.resize_to(2200, 1200)
    sign_in "david@37signals.com"
    visit room_path(rooms(:watercooler))

    width = page.evaluate_script("document.querySelector('#channels').getBoundingClientRect().width")
    assert_operator width, :>, 18 * 16
    assert_operator width, :<=, 22 * 16
  end

  test "opens server settings from the server header menu" do
    sign_in "david@37signals.com"
    visit room_path(rooms(:watercooler))

    find("summary.context-menu__trigger", text: accounts(:signal).name).click
    assert_selector ".channel-list__server-menu[open] .context-menu__menu", text: "Server Settings"

    click_on "Server Settings"

    assert_current_path edit_account_path
    assert_selector "nav[aria-label='Account settings']"
  end
end
