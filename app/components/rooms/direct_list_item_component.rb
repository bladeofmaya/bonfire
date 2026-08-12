class Rooms::DirectListItemComponent < ApplicationComponent
  attr_reader :room, :participants, :sort_timestamp

  def initialize(room:, participants:, sort_timestamp:, unread: false, avatar_source: nil)
    @room = room
    @participants = participants
    @sort_timestamp = sort_timestamp
    @unread = unread
    @avatar_source = avatar_source
  end

  def unread?
    @unread
  end

  def grouped?
    participants.many?
  end

  def accessible_name
    "Ping with #{participants.map(&:name).to_sentence}"
  end

  def abbreviated_names
    if grouped?
      participants.map { |participant| initials_for(participant) }.to_sentence(two_words_connector: "+")
    else
      participants.first.name.split.first
    end
  end

  def avatar_source_for(participant)
    @avatar_source || helpers.fresh_user_avatar_path(participant)
  end

  private
    def initials_for(participant)
      participant.name.split.first(3).map { |part| part.first.capitalize }.join
    end
end
