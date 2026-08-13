require "application_system_test_case"

class VisualRegressionTest < ApplicationSystemTestCase
  setup do
    sign_in "david@37signals.com"
  end

  test "room shell, message history, and composer" do
    join_room rooms(:watercooler)

    assert_visual_match "room-sidebar", selector: "#user_sidebar .sidebar__container"
    assert_visual_match "room-members", selector: "#sidebar .member-sidebar"
    assert_visual_match "room-messages", selector: "##{dom_id(rooms(:watercooler), :messages)}"
    assert_visual_match "room-composer", selector: "footer .composer"
  end

  test "account settings" do
    visit edit_account_path

    assert_selector "section.panel input[value='#{accounts(:signal).name}']"
    assert_visual_match "account-settings", selector: "section.panel"
  end

  test "user profile" do
    visit user_profile_path

    assert_selector "section.panel", text: "Appearance"
    assert_visual_match "user-profile", selector: "section.panel"
  end
end
