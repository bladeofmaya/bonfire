class Rooms::StreamPlayerComponent < ApplicationComponent
  STATES = %w[ offline connecting live reconnecting unauthorized error ].freeze

  attr_reader :room

  def initialize(room:)
    @room = room
  end

  def title
    room.stream_title.presence || room.name
  end
end
