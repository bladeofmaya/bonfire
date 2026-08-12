class Prototype::SettingsFieldComponent < ApplicationComponent
  attr_reader :id, :name, :label, :value, :help, :error

  def initialize(id:, name:, label:, value: nil, help: nil, error: nil, disabled: false)
    @id = id
    @name = name
    @label = label
    @value = value
    @help = help
    @error = error
    @disabled = disabled
  end

  def disabled?
    @disabled
  end

  def described_by
    [ help_id_if_present, error_id_if_present ].compact.join(" ").presence
  end

  private
    def help_id_if_present
      "#{id}_help" if help.present?
    end

    def error_id_if_present
      "#{id}_error" if error.present?
    end
end
