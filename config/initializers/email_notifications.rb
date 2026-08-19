Rails.application.configure do
  config.x.email_notifications = ActiveSupport::OrderedOptions.new
  config.x.email_notifications.enabled = ENV["EMAIL_NOTIFICATIONS_ENABLED"] == "true"
  config.x.email_notifications.from = ENV.fetch("EMAIL_FROM", "Bonfire <notifications@localhost>")
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST", ENV.fetch("TLS_DOMAIN", "localhost")),
    protocol: ENV.fetch("MAILER_PROTOCOL", "https")
  }

  if config.x.email_notifications.enabled
    required = %w[SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD MAILER_HOST]
    missing = required.select { |name| ENV[name].blank? }
    raise "Email notifications are enabled but these variables are missing: #{missing.join(', ')}" if missing.any?

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: Integer(ENV.fetch("SMTP_PORT")),
      user_name: ENV.fetch("SMTP_USERNAME"),
      password: ENV.fetch("SMTP_PASSWORD"),
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain"),
      enable_starttls_auto: ENV.fetch("SMTP_STARTTLS", "true") == "true"
    }
  end
end

Rails.application.config.after_initialize do
  if ENV["RUN_RESQUE_SCHEDULER"] == "true" && defined?(Resque) && defined?(Resque::Scheduler)
    Resque.schedule = YAML.load_file(Rails.root.join("config/resque_schedule.yml"))
  end
end
