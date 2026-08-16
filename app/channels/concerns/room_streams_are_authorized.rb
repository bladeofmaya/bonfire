# Prepended onto Turbo::StreamsChannel. The subscriber names the channel it wants, so
# authorizing room messages or presence only in their dedicated channels would leave the
# stock channel as a way around it: same signed stream name, no membership check. Turn
# those names away here so the membership-authorized channels are the only doors.
module RoomStreamsAreAuthorized
  def subscribed
    stream_name = verified_stream_name_from_params
    if RoomMessagesChannel.guarded_stream?(stream_name) || RoomPresenceChannel.guarded_stream?(stream_name)
      reject
    else
      super
    end
  end
end
