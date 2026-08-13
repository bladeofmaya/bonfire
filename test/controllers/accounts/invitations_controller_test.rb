require "test_helper"

class Accounts::InvitationsControllerTest < ActionDispatch::IntegrationTest
  test "administrators can open the invitation dialog" do
    sign_in :david

    get account_invitation_url

    assert_response :success
    assert_select "turbo-frame#account_invitation_dialog dialog.invitation-dialog[data-controller='invite-dialog']"
    assert_select "#invite_url[value='#{join_url(accounts(:signal).join_code)}']"
  end

  test "members cannot open the invitation dialog" do
    sign_in :jz

    get account_invitation_url

    assert_response :forbidden
  end
end
