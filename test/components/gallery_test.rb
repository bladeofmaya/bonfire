require "test_helper"

class ComponentGalleryTest < ActionDispatch::IntegrationTest
  test "groups production previews separately from prototype evidence" do
    get preview_view_components_path, params: { theme: "light", viewport: "mobile" }

    assert_response :success
    assert_select "html[data-theme='light']"
    assert_select "body.component-preview-layout"
    assert_select "main.component-preview[data-viewport='mobile']"
    assert_select "h1", text: "Bonfire component gallery"
    assert_select "#preview-group-messages", text: "Messages"
    assert_select "#preview-group-rooms", text: "Rooms"
    assert_select "#preview-group-ui", text: "UI primitives"
    assert_select "#preview-group-prototype", text: "Prototype evidence"
    assert_select "a[href*='rooms/shared_list_item_component'][href*='theme=light'][href*='viewport=mobile']"
  end

  test "renders a preview state with persistent display controls" do
    get preview_view_component_path("rooms/shared_list_item_component/long_name"),
      params: { theme: "light", viewport: "mobile" }

    assert_response :success
    assert_select "html[data-theme='light']"
    assert_select "main.component-preview[data-viewport='mobile']"
    assert_select ".component-preview__breadcrumb", text: /Shared List Item.*Long Name/m
    assert_select ".component-preview__stage", text: /Announcements and important community updates/
    assert_select ".component-preview__option.active", count: 2
    assert_select "a.component-preview__home[href*='theme=light'][href*='viewport=mobile']"
  end

  test "renders every production preview state through its gallery URL" do
    ViewComponent::Preview.all.reject { |preview| preview.preview_name.start_with?("prototype/") }.each do |preview|
      preview.examples.each do |example|
        get preview_view_component_path("#{preview.preview_name}/#{example}")

        assert_response :success, "Expected #{preview.preview_name}/#{example} to render"
      end
    end
  end

  test "avatar previews use a real asset instead of a nonexistent preview user route" do
    get preview_view_component_path("messages/boost_component/text")

    assert_response :success
    assert_select ".boost__avatar img[src*='default-avatar']", count: 1 do |images|
      get URI.parse(images.first["src"]).path
      assert_response :success
    end
  end
end
