class EmailNotificationDelivery < ApplicationRecord
  belongs_to :user
  belongs_to :message, optional: true

  enum :kind, %w[ mention daily_summary ].index_by(&:itself), prefix: true

  validates :message, presence: true, if: :kind_mention?
  validates :period_on, presence: true, if: :kind_daily_summary?
end
