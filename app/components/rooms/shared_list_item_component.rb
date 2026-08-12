class Rooms::SharedListItemComponent < ApplicationComponent
  with_collection_parameter :room

  attr_reader :room, :sort_key

  def initialize(room:, sort_key: room.name, unread: false)
    @room = room
    @sort_key = sort_key
    @unread = unread
  end

  def unread?
    @unread
  end
end
