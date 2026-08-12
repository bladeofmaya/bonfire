require "test_helper"

class Rooms::InvolvementButtonComponentTest < ComponentTestCase
  INVOLVEMENTS = {
    "mentions" => "Notifying about @ mentions",
    "everything" => "Notifying about all messages",
    "nothing" => "Notifications are off",
    "invisible" => "Notifications are off and room invisible in sidebar"
  }

  test "renders every involvement state with its explicit next action" do
    INVOLVEMENTS.each do |involvement, label|
      render_inline component(involvement: involvement, label: label)

      assert_component_root "form.button_to"
      assert_selector "button.btn.#{involvement}[role='checkbox'][aria-checked='true'][aria-labelledby='room_involvement_label']"
      assert_selector "input[type='hidden'][name='_method'][value='put']", visible: false
      assert_selector "input[type='hidden'][name='involvement'][value='nothing']", visible: false
      assert_selector "img[aria-hidden='true'][src*='notification-bell-#{involvement}']"
      assert_selector "#room_involvement_label.for-screen-reader", text: label
    end
  end

  test "uses the supplied action without deriving room policy" do
    render_inline component(next_involvement: "invisible")

    assert_selector "form[action='/rooms/123/involvement']"
    assert_selector "input[name='involvement'][value='invisible']", visible: false
  end

  test "rejects unsupported current and next states" do
    assert_raises(ArgumentError) { component(involvement: "loud") }
    assert_raises(ArgumentError) { component(next_involvement: "loud") }
  end

  private
    def component(**overrides)
      Rooms::InvolvementButtonComponent.new(**{
        involvement: "everything",
        next_involvement: "nothing",
        url: "/rooms/123/involvement",
        label: "Notifying about all messages",
        label_id: "room_involvement_label"
      }.merge(overrides))
    end
end
