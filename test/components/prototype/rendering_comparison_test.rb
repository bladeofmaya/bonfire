require "test_helper"

class Prototype::RenderingComparisonTest < ComponentTestCase
  SETTINGS_STATES = [
    {},
    { value: nil },
    { disabled: true },
    { error: "Enter a notice." },
    { value: "A long notice " * 20 }
  ]

  test "settings component and explicit-local partial have matching semantic markup" do
    SETTINGS_STATES.each do |state|
      component_html = render_inline(Prototype::SettingsFieldComponent.new(**settings_options.merge(state))).to_html
      partial_html = render_partial("prototypes/partials/settings_field", settings_options.merge(state))

      assert_equal normalized(component_html), normalized(partial_html)
    end
  end

  test "shared-room component and explicit-local partial have matching markup" do
    [ false, true ].each do |unread|
      room = rooms(:watercooler)
      component_html = render_inline(Prototype::SharedRoomItemComponent.new(room: room, unread: unread)).to_html
      partial_html = render_partial("prototypes/partials/shared_room_item", room: room, unread: unread)

      assert_equal normalized(component_html), normalized(partial_html)
    end
  end

  private
    def settings_options
      {
        id: "account_notice",
        name: "account[notice]",
        label: "Data-protection notice",
        value: "Community policy",
        help: "Shown before signup.",
        error: nil,
        disabled: false
      }
    end

    def render_partial(path, locals)
      render_in_view_context do
        render partial: path, locals: locals
      end.to_html
    end

    def normalized(html)
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("[data-prototype]").remove_attr("data-prototype")
      fragment.to_html
    end
end
