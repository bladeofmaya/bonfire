require "test_helper"

class Prototype::PreviewsTest < ComponentTestCase
  test "renders every settings component state in light mobile preview mode" do
    %i[ normal empty disabled error long_text ].each do |state|
      render_preview state, from: Prototype::SettingsFieldComponentPreview,
        params: { theme: "light", viewport: "mobile" }

      assert_selector "html[data-theme='light']"
      assert_selector "main[data-viewport='mobile'] .settings-field[data-prototype='view-component']"
    end
  end

  test "renders every shared-room component state in dark desktop preview mode" do
    %i[ normal unread long_text ].each do |state|
      render_preview state, from: Prototype::SharedRoomItemComponentPreview,
        params: { theme: "dark", viewport: "desktop" }

      assert_selector "html[data-theme='dark']"
      assert_selector "main[data-viewport='desktop'] a.room"
    end
  end

  test "renders matching partial states through the same preview layout" do
    %i[
      settings_normal settings_empty settings_disabled settings_error settings_long_text
      room_normal room_unread room_long_text
    ].each do |state|
      render_preview state, from: Prototype::PartialPreview,
        params: { theme: "dark", viewport: "mobile" }

      assert_selector "html[data-theme='dark'] main[data-viewport='mobile']"
      assert_selector "[data-prototype='partial'], a.room"
    end
  end
end
