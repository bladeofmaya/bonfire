class Rooms::SharedListItemComponent < ApplicationComponent
  with_collection_parameter :room

  attr_reader :room, :position, :sort_key

  def initialize(room:, position: room.position, sort_key: room.name, unread: false, selected: false, reorderable: false, **)
    @room = room
    @position = position
    @sort_key = sort_key
    @unread = unread
    @selected = selected
    @reorderable = reorderable
  end

  def unread?
    @unread
  end

  def selected?
    @selected
  end

  def reorderable? = @reorderable
end
