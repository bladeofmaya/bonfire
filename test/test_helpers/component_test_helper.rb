module ComponentTestHelper
  def assert_component_root(selector, count: 1)
    assert_selector selector, count: count
  end

  def assert_icon_button(label)
    assert_selector "button[aria-label='#{label}'], a[aria-label='#{label}']"
  end

  def assert_stimulus_contract(controller:, action: nil)
    selector = "[data-controller~='#{controller}']"
    selector += "[data-action~='#{action}']" if action

    assert_selector selector
  end
end
