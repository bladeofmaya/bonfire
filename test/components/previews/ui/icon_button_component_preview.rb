class Ui::IconButtonComponentPreview < ViewComponent::Preview
  def default
    render component
  end

  def reversed
    render component(variant: :reversed)
  end

  def danger
    render component(icon: "trash.svg", label: "Delete message", variant: :danger)
  end

  def success
    render component(icon: "check.svg", label: "Saved", variant: :success)
  end

  def plain
    render component(variant: :plain)
  end

  def disabled
    render component(disabled: true)
  end

  def long_label
    render component(label: "Copy this community invitation link to the clipboard")
  end

  private
    def component(**overrides)
      Ui::IconButtonComponent.new(**{
        label: "Copy join link",
        icon: "copy-paste.svg"
      }.merge(overrides))
    end
end
