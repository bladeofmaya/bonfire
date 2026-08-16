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

  def direct_player? = Streaming::Configuration.direct_player_enabled?

  def media_url
    "#{room.stream_player_origin}/hls/#{room.stream_path}/index.m3u8"
  end
end
