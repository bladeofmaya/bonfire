class Prototype::SettingsFieldComponentPreview < ViewComponent::Preview
  def normal
    render Prototype::SettingsFieldComponent.new(**settings_field_options)
  end

  def empty
    render Prototype::SettingsFieldComponent.new(**settings_field_options(value: nil))
  end

  def disabled
    render Prototype::SettingsFieldComponent.new(**settings_field_options(disabled: true))
  end

  def error
    render Prototype::SettingsFieldComponent.new(**settings_field_options(error: "Enter a notice before publishing."))
  end

  def long_text
    render Prototype::SettingsFieldComponent.new(**settings_field_options(value: long_notice))
  end

  private
    def settings_field_options(**overrides)
      {
        id: "account_data_protection_notice",
        name: "account[data_protection_notice]",
        label: "Data-protection notice",
        value: "We explain how community account data is used.",
        help: "Shown to people before they create an account.",
        error: nil,
        disabled: false
      }.merge(overrides)
    end

    def long_notice
      "This community is independently operated. Contact the administrator if you want to access, correct, export, or remove information connected to your account."
    end
end
