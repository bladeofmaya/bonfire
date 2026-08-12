class Rooms::NotificationBellComponentPreview < ViewComponent::Preview
  def loading
    render component
  end

  def alert
    render component(alert: true)
  end

  def direct_ping
    render component(label: "Notification settings for this Ping")
  end

  private
    def component(**overrides)
      Rooms::NotificationBellComponent.new(**{
        label: "Notification settings for this room"
      }.merge(overrides))
    end
end
