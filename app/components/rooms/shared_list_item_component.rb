class Rooms::SharedListItemComponent < ApplicationComponent
  with_collection_parameter :room

  attr_reader :room, :position, :sort_key

  def initialize(room:, position: room.position, sort_key: room.name, unread: false, unread_mention_count: 0, selected: false, reorderable: false, **)
    @room = room
    @position = position
    @sort_key = sort_key
    @unread = unread
    @unread_mention_count = unread_mention_count
    @selected = selected
    @reorderable = reorderable
  end

  def unread?
    @unread
  end

  attr_reader :unread_mention_count

  def mentioned? = unread_mention_count.positive?

  def selected?
    @selected
  end

  def reorderable? = @reorderable
  def streaming? = room.stream_live?
end
