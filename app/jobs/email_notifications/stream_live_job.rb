class EmailNotifications::StreamLiveJob < ApplicationJob
  queue_as :email
  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, IOError, SocketError, wait: :polynomially_longer, attempts: 5
  retry_on Postmark::HttpServerError, Postmark::TimeoutError, wait: :polynomially_longer, attempts: 5
  discard_on Net::SMTPFatalError
  discard_on Postmark::InvalidApiKeyError, Postmark::InvalidEmailRequestError, Postmark::InactiveRecipientError

  def perform(room, session_id)
    return unless Rails.configuration.x.email_notifications.enabled
    return unless room.stream_session_id == session_id && room.stream_live?

    recipients(room).find_each do |user|
      delivery = EmailNotificationDelivery.find_or_create_by!(
        user:, room:, stream_session_id: session_id, kind: :stream_live
      )
      delivery.with_lock do
        next if delivery.delivered_at?

        NotificationMailer.with(user:, room:).stream_live.deliver_now
        delivery.update!(delivered_at: Time.current)
        ActiveSupport::Notifications.instrument("email_notification.delivered", kind: "stream_live")
      end
    end
  end

  private
    def recipients(room)
      User.active.without_bots
        .where(email_notifications_enabled: true, email_stream_live_enabled: true)
        .joins(:memberships)
        .merge(Membership.visible.where(room:))
        .distinct
    end
end
