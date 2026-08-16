require "test_helper"

class Ui::FlashMessageComponentTest < ComponentTestCase
  test "renders a persistent, dismissible notice with visible text" do
    render_inline Ui::FlashMessageComponent.new(message: "Settings saved")

    assert_component_root ".flash.flash--notice[role='status'][aria-live='polite'][aria-atomic='true']"
    assert_selector ".flash__message", text: "Settings saved"
    assert_selector ".flash__icon img[src*='check']"
    assert_icon_button "Dismiss notification"
    assert_selector "button[data-action='element-removal#remove']"
    assert_no_selector "[data-action*='animationend']"
  end

  test "renders an assertive alert" do
    render_inline Ui::FlashMessageComponent.new(message: "Room not found or inaccessible", kind: :alert)

    assert_component_root ".flash.flash--alert[role='alert'][aria-live='assertive']"
    assert_selector ".flash__message", text: "Room not found or inaccessible"
    assert_selector ".flash__icon img[src*='alert']"
  end

  test "requires a message and supported kind" do
    assert_raises(ArgumentError) { Ui::FlashMessageComponent.new(message: "") }
    assert_raises(ArgumentError) { Ui::FlashMessageComponent.new(message: "Nope", kind: :warning) }
  end
end
