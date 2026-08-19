class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.email_notifications.from }
  after_action :set_postmark_message_stream
  layout "mailer"

  private
    def set_postmark_message_stream
      if Rails.configuration.x.email_notifications.provider == "postmark" && message.respond_to?(:message_stream=)
        message.message_stream = Rails.configuration.x.email_notifications.message_stream
      end
    end
end
