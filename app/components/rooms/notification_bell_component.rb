class Rooms::NotificationBellComponent < ApplicationComponent
  attr_reader :label

  def initialize(label:, alert: false)
    raise ArgumentError, "label must be present" if label.blank?

    @label = label
    @alert = alert
  end

  def alert?
    @alert
  end
end
