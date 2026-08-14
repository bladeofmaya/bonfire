class Rooms::SharedListItemComponent < ApplicationComponent
  with_collection_parameter :room

  attr_reader :room, :sort_key

  def initialize(room:, sort_key: room.name, unread: false, selected: false)
    @room = room
    @sort_key = sort_key
    @unread = unread
    @selected = selected
  end

  def unread?
    @unread
  end

  def selected?
    @selected
  end
end
