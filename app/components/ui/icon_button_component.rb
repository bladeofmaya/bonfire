class Ui::IconButtonComponent < ApplicationComponent
  VARIANT_CLASSES = {
    default: nil,
    reversed: "btn--reversed",
    danger: "btn--negative",
    success: "btn--success",
    plain: "btn--plain"
  }.freeze
  TYPES = %i[ button submit reset ].freeze

  attr_reader :label, :icon, :type, :form, :data

  def initialize(label:, icon:, variant: :default, type: :button, disabled: false, form: nil, data: {})
    raise ArgumentError, "label must be present" if label.blank?
    raise ArgumentError, "icon must be present" if icon.blank?
    raise ArgumentError, "unsupported variant: #{variant}" unless VARIANT_CLASSES.key?(variant)
    raise ArgumentError, "unsupported button type: #{type}" unless TYPES.include?(type)

    @label = label
    @icon = icon
    @variant = variant
    @type = type
    @disabled = disabled
    @form = form
    @data = data
  end

  def css_classes
    [ "btn", "btn--icon", VARIANT_CLASSES.fetch(@variant) ].compact
  end

  def disabled?
    @disabled
  end
end
