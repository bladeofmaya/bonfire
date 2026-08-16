class RoomPresenceChannel < ApplicationCable::Channel
  extend Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  STREAM_SUFFIX = "presence"

  def self.guarded_stream?(stream_name)
    stream_name.to_s.split(":", 2).second == STREAM_SUFFIX
  end

  def subscribed
    if stream_name = authorized_stream_name
      stream_from stream_name
    else
      reject
    end
  end

  private
    def authorized_stream_name
      stream_name = verified_stream_name_from_params
      gid_param, suffix = stream_name.to_s.split(":", 2)
      room = GlobalID::Locator.locate(gid_param, only: Room) if suffix == STREAM_SUFFIX
      stream_name if room && current_user.rooms.exists?(room.id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
end
