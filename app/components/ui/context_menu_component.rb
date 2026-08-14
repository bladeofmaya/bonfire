class Ui::ContextMenuComponent < ApplicationComponent
  Item = Data.define(:label, :url, :icon, :data)

  attr_reader :label, :items, :menu_class

  def initialize(label:, items:, menu_class: nil)
    @label = label
    @items = items.map do |item|
      Item.new(
        label: item.fetch(:label),
        url: item.fetch(:url),
        icon: item[:icon],
        data: item.fetch(:data, {})
      )
    end
    @menu_class = menu_class
  end

  def render?
    items.any?
  end
end
