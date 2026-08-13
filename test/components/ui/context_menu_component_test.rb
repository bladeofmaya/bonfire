require "test_helper"

class Ui::ContextMenuComponentTest < ComponentTestCase
  test "renders a reusable popup trigger and menu items" do
    render_inline Ui::ContextMenuComponent.new(
      label: "Server menu",
      items: [ { label: "Server Settings", url: "/account/edit", icon: "settings.svg" } ]
    ) do
      "Example server"
    end

    assert_component_root "details.context-menu[data-controller='popup']"
    assert_selector "summary.context-menu__trigger[aria-label='Server menu']", text: "Example server"
    assert_selector ".context-menu__chevron", count: 1
    assert_selector "menu.context-menu__menu[data-popup-target='menu'][aria-label='Server menu']", visible: false do
      assert_selector "a.context-menu__item[href='/account/edit'][data-action='popup#close']", text: "Server Settings", visible: false
      assert_selector "img[src*='settings']", count: 1, visible: false
    end
  end
end
