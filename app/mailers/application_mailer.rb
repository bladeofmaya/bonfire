class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.email_notifications.from }
  layout "mailer"
end
