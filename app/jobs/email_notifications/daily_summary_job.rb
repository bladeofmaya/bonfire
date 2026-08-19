class EmailNotifications::DailySummaryJob < ApplicationJob
  queue_as :email
  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, IOError, SocketError, wait: :polynomially_longer, attempts: 5
  discard_on Net::SMTPFatalError

  def perform(user, period_on)
    return unless user.email_notifications_available? && user.email_notifications_enabled? && user.email_daily_summary_enabled?

    delivery = EmailNotificationDelivery.find_or_create_by!(user:, period_on:, kind: :daily_summary)
    delivery.with_lock do
      return if delivery.delivered_at?

      messages = unread_messages_for(user, period_on)
      NotificationMailer.with(user:, messages:, period_on:).daily_summary.deliver_now if messages.any?
      delivery.update!(delivered_at: Time.current)
      ActiveSupport::Notifications.instrument("email_notification.delivered", kind: "daily_summary", empty: messages.empty?)
    end
  end

  private
    def unread_messages_for(user, period_on)
      zone = ActiveSupport::TimeZone[user.email_time_zone]
      range = zone.local(period_on.year, period_on.month, period_on.day).all_day
      room_ids = user.memberships.unread.select(:room_id)

      Message.joins(:room).where(room_id: room_ids, created_at: range, rooms: { stream_enabled: false }).where.not(creator: user)
        .with_rich_text_body.includes(:room, :creator).order(:created_at).to_a
    end
end
