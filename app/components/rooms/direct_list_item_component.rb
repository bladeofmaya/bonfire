class Rooms::DirectListItemComponent < ApplicationComponent
  attr_reader :room, :participants, :sort_timestamp

  def initialize(room:, participants:, sort_timestamp:, unread_count: 0, avatar_source: nil)
    @room = room
    @participants = participants
    @sort_timestamp = sort_timestamp
    @unread_count = unread_count
    @avatar_source = avatar_source
  end

  def unread?
    unread_count.positive?
  end

  attr_reader :unread_count

  def grouped?
    participants.many?
  end

  def accessible_name
    "Ping with #{participants.map(&:name).to_sentence}"
  end

  def display_names
    participants.map(&:name).to_sentence
  end

  def avatar_source_for(participant)
    @avatar_source || helpers.fresh_user_avatar_path(participant)
  end

end
