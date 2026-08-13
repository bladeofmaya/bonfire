require "application_system_test_case"

class AccountInvitationTest < ApplicationSystemTestCase
  test "administrator opens the invitation dialog from the server header" do
    sign_in "david@37signals.com"
    visit room_path(rooms(:watercooler))

    assert_selector "a.channel-list__invite svg.lucide-user-round-plus"
    click_on "Invite people"

    assert_selector "dialog.invitation-dialog[open]", text: "Invite people to #{accounts(:signal).name}"
    assert_field "invite_url", with: join_url(accounts(:signal).join_code), readonly: true

    find("button[aria-label='Close invitation']").click
    assert_no_selector "dialog.invitation-dialog[open]"
  end

  test "member does not see invitation access" do
    sign_in "jz@37signals.com"
    visit room_path(rooms(:watercooler))

    assert_no_selector "a.channel-list__invite"
  end
end
