Rails.application.config.after_initialize do
  Streaming::Configuration.validate_startup!
end
