require "application_system_test_case"

class ThemeTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    sign_in "david@37signals.com"
    visit user_profile_url
    click_on "Appearance"
  end

  test "choosing and remembering a color theme" do
    select "Light", from: "Theme"

    assert_selector "html[data-theme='light']", visible: false
    assert_equal "light", page.evaluate_script("localStorage.getItem('bonfire-theme')")
    assert_equal "#fdf8f0", css_variable("--color-app-bg")

    visit user_profile_url
    click_on "Appearance"

    assert_selector "html[data-theme='light']", visible: false
    assert_select "Theme", selected: "Light"

    select "Dark", from: "Theme"

    assert_selector "html[data-theme='dark']", visible: false
    assert_equal "dark", page.evaluate_script("localStorage.getItem('bonfire-theme')")
    assert_equal "#181510", css_variable("--color-app-bg")
  end

  test "returning to the system theme clears the override" do
    select "Light", from: "Theme"
    select "Use system setting", from: "Theme"

    assert_nil page.evaluate_script("localStorage.getItem('bonfire-theme')")
    assert_selector "html[data-theme]", visible: false
  end

  test "avatar upload controls remain transparent in both themes" do
    [ "Light", "Dark" ].each do |theme|
      select theme, from: "Theme"

      all(".input--file input[type='file']", visible: false).each do |input|
        assert_equal "rgba(0, 0, 0, 0)", computed_style(input, "backgroundColor")
      end
    end
  end

  private
    def css_variable(name)
      page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('#{name}').trim()")
    end

    def computed_style(element, property)
      page.evaluate_script("getComputedStyle(arguments[0])[arguments[1]]", element, property)
    end
end
