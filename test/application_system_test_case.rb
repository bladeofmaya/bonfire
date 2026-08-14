require "test_helper"

WebMock.disable!

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include SystemTestHelper
  include VisualRegressionHelper

  setup do
    page.current_window.resize_to(1400, 1400)
  end
end
