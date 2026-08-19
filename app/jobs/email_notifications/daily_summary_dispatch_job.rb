class EmailNotifications::DailySummaryDispatchJob < ApplicationJob
  queue_as :email

  def perform(now = Time.current)
    return unless Rails.configuration.x.email_notifications.enabled

    User.active.where(email_notifications_enabled: true, email_daily_summary_enabled: true).find_each do |user|
      local_now = now.in_time_zone(user.email_time_zone)
      next unless local_now.hour == user.email_digest_hour

      EmailNotifications::DailySummaryJob.perform_later(user, local_now.to_date - 1)
    end
  end
end
