class Prototype::SharedRoomItemComponent < ApplicationComponent
  with_collection_parameter :room

  attr_reader :room

  def initialize(room:, unread: false)
    @room = room
    @unread = unread
  end

  def unread?
    @unread
  end
end
