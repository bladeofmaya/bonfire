Rails.application.configure do
  config.x.email_notifications = ActiveSupport::OrderedOptions.new
  config.x.email_notifications.enabled = ENV["EMAIL_NOTIFICATIONS_ENABLED"] == "true"
  config.x.email_notifications.provider = ENV.fetch("EMAIL_PROVIDER", "postmark")
  config.x.email_notifications.from = ENV.fetch("EMAIL_FROM", "Bonfire <notifications@localhost>")
  config.x.email_notifications.message_stream = ENV.fetch("POSTMARK_MESSAGE_STREAM", "outbound")
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", ENV.fetch("TLS_DOMAIN", "localhost")),
    protocol: ENV.fetch("MAILER_PROTOCOL", "https")
  }

  if config.x.email_notifications.enabled
    required = %w[EMAIL_FROM MAILER_HOST]
    required += case config.x.email_notifications.provider
    when "postmark" then %w[POSTMARK_SERVER_TOKEN]
    when "smtp" then %w[SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD]
    else
      raise "Unsupported EMAIL_PROVIDER: #{config.x.email_notifications.provider.inspect}"
    end
    missing = required.select { |name| ENV[name].blank? }
    raise "Email notifications are enabled but these variables are missing: #{missing.join(', ')}" if missing.any?

    if config.x.email_notifications.provider == "postmark"
      config.action_mailer.delivery_method = :postmark
      config.action_mailer.postmark_settings = { api_token: ENV.fetch("POSTMARK_SERVER_TOKEN") }
    else
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.smtp_settings = {
        address: ENV.fetch("SMTP_ADDRESS"), port: Integer(ENV.fetch("SMTP_PORT")),
        user_name: ENV.fetch("SMTP_USERNAME"), password: ENV.fetch("SMTP_PASSWORD"),
        authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain"),
        enable_starttls_auto: ENV.fetch("SMTP_STARTTLS", "true") == "true"
      }
    end
  end
end

Rails.application.config.after_initialize do
  if ENV["RUN_RESQUE_SCHEDULER"] == "true" && defined?(Resque) && defined?(Resque::Scheduler)
    Resque.schedule = YAML.load_file(Rails.root.join("config/resque_schedule.yml"))
  end
end
