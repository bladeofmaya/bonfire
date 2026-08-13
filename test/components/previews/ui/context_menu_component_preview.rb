class Ui::ContextMenuComponentPreview < ViewComponent::Preview
  def server
    render Ui::ContextMenuComponent.new(
      label: "Server menu",
      items: [ { label: "Server Settings", url: "#", icon: "settings.svg" } ]
    ) do
      "Maya's Veil"
    end
  end
end
