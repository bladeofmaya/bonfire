module Room::Streaming
  extend ActiveSupport::Concern

  HEARTBEAT_TTL = 45.seconds

  included do
    scope :with_fresh_stream, -> { where(stream_last_seen_at: HEARTBEAT_TTL.ago..) }
  end

  def stream_live?
    stream_enabled? && stream_session_id.present? && stream_last_seen_at.present? && stream_last_seen_at >= HEARTBEAT_TTL.ago
  end

  def stream_live_until
    stream_last_seen_at + HEARTBEAT_TTL if stream_live?
  end

  def stream_viewers
    memberships.connected.includes(user: { avatar_attachment: :blob }).map(&:user).select(&:active?).sort_by { |user| user.name.downcase }
  end

  def broadcast_stream_viewers
    broadcast_replace_to self, :presence, target: [ self, :stream_viewers ],
      partial: "rooms/show/stream_viewers", locals: { room: self, viewers: stream_viewers }
  end

  def apply_stream_event!(type:, session_id:, occurred_at:)
    case type
    when "stream.started"
      was_live = stream_live?
      update!(stream_session_id: session_id, stream_live_at: occurred_at, stream_last_seen_at: occurred_at)
      stream_went_live! unless was_live
    when "stream.heartbeat"
      return false unless stream_session_id == session_id

      update!(stream_last_seen_at: [ stream_last_seen_at, occurred_at ].compact.max)
    when "stream.stopped"
      return false unless stream_session_id == session_id

      update!(stream_session_id: nil, stream_live_at: nil, stream_last_seen_at: nil)
    else
      raise ArgumentError, "Unsupported stream event"
    end

    broadcast_stream_state
    true
  end

  def clear_stream_state!
    return unless stream_session_id? || stream_live_at? || stream_last_seen_at?

    update_columns stream_session_id: nil, stream_live_at: nil, stream_last_seen_at: nil, updated_at: Time.current
  end

  private
    def stream_went_live!
      return if stream_notified_session_id == stream_session_id

      update!(stream_notified_session_id: stream_session_id)
      Room::PushStreamLiveJob.perform_later(self, stream_session_id)
    end

    def broadcast_stream_state
      users.active.find_each do |user|
        membership = memberships.find_by!(user: user)
        next if membership.involved_in_invisible?

        broadcast_replace_to user, :rooms, target: [ self, :list ],
          partial: "users/sidebars/rooms/shared",
          locals: {
            room: self, unread: membership.unread?, unread_mention_count: membership.unread_mention_count,
            administrator: user.administrator?
          }
      end
    end
end
