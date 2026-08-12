require "test_helper"

class Rooms::DirectPlaceholderComponentTest < ComponentTestCase
  test "renders a participant-specific start action" do
    user = users(:kevin)

    render_inline component(user)

    assert_component_root "form.button_to"
    assert_selector "form[action='#{directs_path(user)}'][method='post']"
    assert_selector "button.direct[aria-label='Start a ping with #{user.name}']"
    assert_selector ".direct__author [aria-hidden='true']", text: user.name.split.first
  end

  test "keeps the avatar decorative and versioned through the fresh route" do
    user = users(:kevin)

    render_inline component(user)

    assert_selector ".avatar img[aria-hidden='true'][src*='/users/'][src*='/avatar']"
  end

  test "preserves the full accessible name when the visible name is shortened" do
    user = users(:kevin)
    user.name = "Alexandria Cassandra Montgomery"

    render_inline component(user)

    assert_selector "button[aria-label='Start a ping with Alexandria Cassandra Montgomery']"
    assert_selector "[aria-hidden='true']", text: "Alexandria"
  end

  private
    def component(user)
      Rooms::DirectPlaceholderComponent.new(
        user: user,
        url: directs_path(user)
      )
    end

    def directs_path(user)
      Rails.application.routes.url_helpers.rooms_directs_path(user_ids: [ user.id ])
    end
end
