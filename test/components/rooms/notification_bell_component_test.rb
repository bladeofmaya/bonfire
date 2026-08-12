require "test_helper"

class Rooms::NotificationBellComponentTest < ComponentTestCase
  test "renders the loading state with the notification Stimulus contract" do
    render_inline component

    assert_component_root "button.btn.btn--icon[type='button'][aria-label='Notification settings for this room']"
    assert_selector "[data-action='click->notifications#attemptToSubscribe'][data-notifications-target='bell']"
    assert_selector "img[src*='notification-bell-loading'][aria-hidden='true']:not([hidden])"
    assert_selector "img[src*='notification-bell-alert'][aria-hidden='true'][hidden]", visible: false
  end

  test "renders the alert state without changing the controller targets" do
    render_inline component(alert: true)

    assert_selector "img[src*='notification-bell-loading'][hidden]", visible: false
    assert_selector "img[src*='notification-bell-alert']:not([hidden])"
    assert_selector "[data-notifications-target='bell']"
  end

  test "requires a task-oriented accessible label" do
    assert_raises(ArgumentError) { component(label: "") }
  end

  private
    def component(**overrides)
      Rooms::NotificationBellComponent.new(**{
        label: "Notification settings for this room"
      }.merge(overrides))
    end
end
