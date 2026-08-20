class Room::PushStreamLiveJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  def perform(room, session_id)
    return unless room.stream_session_id == session_id && room.stream_live?

    payload = {
      title: room.name,
      body: "#{room.stream_title.presence || room.name} is live now",
      path: Rails.application.routes.url_helpers.room_path(room)
    }

    subscriptions = Push::Subscription.joins(user: :memberships)
      .merge(Membership.visible.where(room: room))
      .merge(User.active.without_bots)
      .distinct

    Rails.configuration.x.web_push_pool.queue(payload, subscriptions)
  end
end
