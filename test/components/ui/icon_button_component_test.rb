require "test_helper"

class Ui::IconButtonComponentTest < ComponentTestCase
  test "renders a native button with an accessible label and decorative icon" do
    render_inline component

    assert_icon_button "Copy join link"
    assert_component_root "button.btn.btn--icon[type='button']"
    assert_selector "img[aria-hidden='true'][src*='copy-paste']"
  end

  test "renders every supported variant" do
    expected_classes = {
      default: nil,
      reversed: "btn--reversed",
      danger: "btn--negative",
      success: "btn--success",
      plain: "btn--plain"
    }

    expected_classes.each do |variant, css_class|
      render_inline component(variant: variant)

      assert_selector "button.btn"
      assert_selector "button.#{css_class}" if css_class
    end
  end

  test "preserves native state, form association, and Stimulus data" do
    render_inline component(
      type: :submit,
      disabled: true,
      form: "invite-form",
      data: { action: "clipboard#copy", clipboard_target: "button" }
    )

    assert_selector "button.btn[type='submit'][disabled][form='invite-form']"
    assert_selector "[data-action='clipboard#copy'][data-clipboard-target='button']"
  end

  test "rejects unsupported variants and button types" do
    assert_raises(ArgumentError) { component(variant: :mystery) }
    assert_raises(ArgumentError) { component(type: :link) }
  end

  test "requires an accessible label and asset name" do
    assert_raises(ArgumentError) { component(label: "") }
    assert_raises(ArgumentError) { component(icon: nil) }
  end

  private
    def component(**overrides)
      Ui::IconButtonComponent.new(**{
        label: "Copy join link",
        icon: "copy-paste.svg"
      }.merge(overrides))
    end
end
