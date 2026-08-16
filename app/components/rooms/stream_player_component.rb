class Rooms::StreamPlayerComponent < ApplicationComponent
  STATES = %w[ offline connecting live reconnecting unauthorized error ].freeze

  attr_reader :room, :viewers

  def initialize(room:, viewers: [])
    @room = room
    @viewers = viewers
  end

  def title
    room.stream_title.presence || room.name
  end
end
