class EmailNotifications::MentionJob < ApplicationJob
  queue_as :email
  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, IOError, SocketError, wait: :polynomially_longer, attempts: 5
  discard_on Net::SMTPFatalError

  OFFLINE_GRACE_PERIOD = 5.minutes

  def perform(message)
    return unless Rails.configuration.x.email_notifications.enabled

    recipients_for(message).find_each do |user|
      membership = user.memberships.find_by(room: message.room)
      next unless membership
      next if membership.connections.positive?
      next unless user.email_notifications_available? && user.email_notifications_enabled? && user.email_mentions_enabled?

      delivery = EmailNotificationDelivery.find_or_create_by!(user:, message:, kind: :mention)
      delivery.with_lock do
        next if delivery.delivered_at?

        NotificationMailer.with(user:, message:).mention.deliver_now
        delivery.update!(delivered_at: Time.current)
        ActiveSupport::Notifications.instrument("email_notification.delivered", kind: "mention")
      end
    end
  end

  private
    def recipients_for(message)
      scope = message.room.users.active.where.not(id: message.creator_id)
      message.room.direct? ? scope : scope.where(id: message.mentionees.select(:id))
    end
end
