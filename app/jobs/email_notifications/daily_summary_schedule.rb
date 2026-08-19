class EmailNotifications::DailySummarySchedule
  @queue = :email

  def self.perform
    EmailNotifications::DailySummaryDispatchJob.perform_now
  end
end
