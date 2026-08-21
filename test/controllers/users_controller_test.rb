require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @join_code = accounts(:signal).join_code
  end

  test "show" do
    sign_in :david
    get user_url(users(:jz))
    assert_response :ok
    assert_select "a[href='mailto:#{users(:jz).email_address}']"
    assert_select "form[action='#{rooms_directs_path(user_ids: [ users(:jz).id ])}'] button", text: "Ping"
  end

  test "member profiles hide email addresses from other members" do
    sign_in :jz

    get user_url(users(:kevin))

    assert_response :ok
    assert_select "a[href^='mailto:']", count: 0
    assert_not_includes response.body, users(:kevin).email_address
  end

  test "new" do
    get join_url(@join_code)
    assert_response :success
    assert_no_match(/Bonfire(?:&trade;|™) version/, response.body)
  end

  test "signup renders configured sanitized README and acknowledgement" do
    accounts(:signal).publish_readme!(%(<h2>Privacy</h2><p>Read our <a href="https://example.com/privacy">privacy policy</a>.</p><script>alert("no")</script>))

    get join_url(@join_code)

    assert_response :success
    assert_select ".signup-card__information" do
      assert_select "h2#readme-title", text: "READ FIRST"
      assert_select "a[href='https://example.com/privacy']", text: "privacy policy"
      assert_select "script", count: 0
    end
    assert_select ".signup-card__form input[name='user[signup_rules_acknowledgement]'][required]"
    assert_not_includes response.body, "alert(&quot;no&quot;)"
  end

  test "signup omits acknowledgement when no README is configured" do
    get join_url(@join_code)

    assert_response :success
    assert_select ".signup-card__information h2", text: "READ FIRST"
    assert_select "input[name='user[signup_rules_acknowledgement]']", count: 0
  end

  test "signup renders administrator-managed rich text sections" do
    account = accounts(:signal)
    account.publish_readme!("<h2>About</h2><p>A community for makers.</p><h2>Etiquette</h2><p>Be generous and constructive.</p>")

    get join_url(@join_code)

    assert_response :success
    assert_select ".signup-readme-content h2", text: "About"
    assert_select ".signup-readme-content h2", text: "Etiquette"
    assert_select "h1", text: "Join #{account.name}"
  end

  test "new does not allow a signed in user" do
    sign_in :david

    get join_url(@join_code)
    assert_redirected_to root_url
  end

  test "new requires a join code" do
    get join_url("not")
    assert_response :not_found
  end

  test "create" do
    previous_enabled = Rails.configuration.x.email_notifications.enabled
    Rails.configuration.x.email_notifications.enabled = true
    begin
      assert_enqueued_with(job: EmailNotifications::NewUserSignupJob) do
        assert_difference -> { User.count }, 1 do
          post join_url(@join_code), params: { user: { name: "New Person", email_address: "new@37signals.com", password: "secret123456" } }
        end
      end
    ensure
      Rails.configuration.x.email_notifications.enabled = previous_enabled
    end

    assert_redirected_to root_url

    user = User.last
    assert_equal user.id, Session.find_by(token: parsed_cookies.signed[:session_token]).user.id
    assert_equal Rooms::Open.all, user.rooms
  end

  test "configured notice requires acknowledgement and preserves entered values" do
    accounts(:signal).publish_readme!("We store your account details.")

    assert_no_difference -> { User.count } do
      post join_url(@join_code), params: {
        user: { name: "New Person", email_address: "new@37signals.com", password: "secret123456" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /must be accepted/
    assert_select "input[name='user[name]'][value='New Person']"
    assert_select "input[name='user[email_address]'][value='new@37signals.com']"
  end

  test "acknowledgement records the published notice metadata atomically" do
    account = accounts(:signal)
    account.publish_readme!("We store your account details.")

    assert_difference -> { User.count }, 1 do
      post join_url(@join_code), params: {
        user: {
          name: "New Person",
          email_address: "new@37signals.com",
          password: "secret123456",
          signup_rules_acknowledgement: "1"
        }
      }, headers: { "REMOTE_ADDR" => "192.0.2.10" }
    end

    user = User.last
    assert_equal account.readme_version, user.readme_version
    assert_equal account.readme_digest, user.readme_digest
    assert user.signup_rules_accepted_at.present?
    assert_equal "192.0.2.10", user.signup_rules_accepted_ip
  end

  test "invalid signup input renders errors instead of raising" do
    assert_no_difference -> { User.count } do
      post join_url(@join_code), params: {
        user: { name: "", email_address: "", password: "short" }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /Name can't be blank/
    assert_select "[role='alert']", text: /Email address can't be blank/
    assert_select "[role='alert']", text: /Password is too short/
  end

  test "creating a new user with an existing email address will redirect to login screen" do
    assert_no_difference -> { User.count } do
      post join_url(@join_code), params: { user: { name: "Another David", email_address: users(:david).email_address, password: "secret123456" } }
    end

    assert_redirected_to new_session_url(email_address: users(:david).email_address)
  end
end
