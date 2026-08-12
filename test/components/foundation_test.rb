require "test_helper"

class ComponentFoundationTest < ActiveSupport::TestCase
  test "uses the shared component base class" do
    assert_operator ApplicationComponent, :<, ViewComponent::Base
  end

  test "configures generators and previews consistently" do
    config = ViewComponent::Base.config

    assert_equal "app/components", config.generate.path
    assert config.generate.preview
    assert_equal "test/components/previews", config.generate.preview_path
    assert_equal [ Rails.root.join("test/components/previews").to_s ], config.previews.paths
    assert_equal "component_preview", config.previews.default_layout
  end
end
