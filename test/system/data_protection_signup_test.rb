require "application_system_test_case"

class DataProtectionSignupTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1000)
    accounts(:signal).publish_readme!("We use your profile information to operate this community.")
  end

  test "accepts the published notice during desktop signup" do
    complete_signup name: "Desktop Member", email: "desktop@example.com"

    assert User.find_by!(email_address: "desktop@example.com").signup_rules_accepted_at.present?
  end

  test "accepts the published notice during mobile signup" do
    page.current_window.resize_to(390, 844)

    complete_signup name: "Mobile Member", email: "mobile@example.com"

    assert User.find_by!(email_address: "mobile@example.com").signup_rules_accepted_at.present?
  end

  test "long README content scrolls without changing entered signup fields" do
    account = accounts(:signal)
    account.publish_readme!(([ "<h2>About this place</h2><p>Be thoughtful.</p>" ] * 20).join)
    visit join_path(account.join_code)

    fill_in "Name", with: "Still Here"
    assert_selector ".signup-readme-content", text: "Be thoughtful"
    assert_field "Name", with: "Still Here"
    assert_selector ".signup-card__form", text: "Join #{account.name}"
  end

  test "two-pane signup composition remains stable on desktop and mobile" do
    accounts(:signal).publish_readme!("<h2>About</h2><p>A private place for our community to stay connected.</p><h2>Etiquette</h2><p>Be kind, constructive, and respectful.</p>")
    visit join_path(accounts(:signal).join_code)

    assert_visual_match "signup-information-desktop", selector: ".signup-card"

    page.current_window.resize_to(390, 844)
    assert_visual_match "signup-information-mobile", selector: ".signup-card"
  end

  private
    def complete_signup(name:, email:)
      visit join_path(accounts(:signal).join_code)

      assert_selector ".signup-readme-content", text: "We use your profile information"
      fill_in "Name", with: name
      fill_in "Email address", with: email
      fill_in "Password", with: "secret123456"
      checkbox = find("#user_signup_rules_acknowledgement")
      checkbox.check
      assert checkbox.checked?
      find("button[type='submit']").click
      assert_selector "turbo-frame#user_sidebar"
      assert_match %r{\A/rooms/\d+\z}, URI.parse(current_url).path
    end
end
