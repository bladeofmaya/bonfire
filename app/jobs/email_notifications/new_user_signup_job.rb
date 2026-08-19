class EmailNotifications::NewUserSignupJob < ApplicationJob
  queue_as :email
  retry_on Net::SMTPServerBusy, Net::SMTPUnknownError, IOError, SocketError, wait: :polynomially_longer, attempts: 5
  retry_on Postmark::HttpServerError, Postmark::TimeoutError, wait: :polynomially_longer, attempts: 5
  discard_on Net::SMTPFatalError
  discard_on Postmark::InvalidApiKeyError, Postmark::InvalidEmailRequestError, Postmark::InactiveRecipientError

  def perform(new_user)
    return unless Rails.configuration.x.email_notifications.enabled

    User.active.without_bots.where(
      role: :administrator,
      email_notifications_enabled: true,
      email_new_user_signup_enabled: true
    ).find_each do |administrator|
      delivery = EmailNotificationDelivery.find_or_create_by!(
        user: administrator, subject_user: new_user, kind: :new_user_signup
      )
      delivery.with_lock do
        next if delivery.delivered_at?

        NotificationMailer.with(user: administrator, new_user:).new_user_signup.deliver_now
        delivery.update!(delivered_at: Time.current)
        ActiveSupport::Notifications.instrument("email_notification.delivered", kind: "new_user_signup")
      end
    end
  end
end
