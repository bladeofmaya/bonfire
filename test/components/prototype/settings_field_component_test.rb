require "test_helper"

class Prototype::SettingsFieldComponentTest < ComponentTestCase
  test "renders an explicitly labelled field with help" do
    render_inline component

    assert_component_root ".settings-field"
    assert_selector "label[for='account_notice']", text: "Data-protection notice"
    assert_selector "textarea#account_notice[name='account[notice]'][aria-describedby='account_notice_help']"
    assert_selector "#account_notice_help", text: "Shown before signup."
    assert_no_selector "[role='alert']"
  end

  test "renders disabled and error states accessibly" do
    render_inline component(disabled: true, error: "Enter a notice.")

    assert_selector "textarea[disabled][aria-invalid='true'][aria-describedby='account_notice_help account_notice_error']"
    assert_selector "#account_notice_error[role='alert']", text: "Enter a notice."
  end

  private
    def component(**overrides)
      Prototype::SettingsFieldComponent.new(**{
        id: "account_notice",
        name: "account[notice]",
        label: "Data-protection notice",
        value: "Community policy",
        help: "Shown before signup."
      }.merge(overrides))
    end
end
