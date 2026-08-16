class Ui::FlashMessageComponent < ApplicationComponent
  KINDS = %i[ notice alert ].freeze

  attr_reader :message, :kind

  def initialize(message:, kind: :notice)
    raise ArgumentError, "message must be present" if message.blank?
    raise ArgumentError, "unsupported kind: #{kind}" unless KINDS.include?(kind)

    @message = message
    @kind = kind
  end

  def css_classes
    [ "flash", "flash--#{kind}" ]
  end

  def role
    alert? ? "alert" : "status"
  end

  def aria_live
    alert? ? "assertive" : "polite"
  end

  def icon
    alert? ? "alert.svg" : "check.svg"
  end

  private
    def alert?
      kind == :alert
    end
end
