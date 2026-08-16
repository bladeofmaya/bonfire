class Ui::FlashMessageComponentPreview < ViewComponent::Preview
  def notice
    render Ui::FlashMessageComponent.new(message: "Account settings saved")
  end

  def alert
    render Ui::FlashMessageComponent.new(message: "Room not found or inaccessible", kind: :alert)
  end

  def long_message
    render Ui::FlashMessageComponent.new(
      message: "You cannot open this channel because your current membership does not include access to it.",
      kind: :alert
    )
  end
end
