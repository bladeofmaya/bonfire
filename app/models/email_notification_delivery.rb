class EmailNotificationDelivery < ApplicationRecord
  belongs_to :user
  belongs_to :message, optional: true
  belongs_to :subject_user, class_name: "User", optional: true

  enum :kind, %w[ mention daily_summary new_user_signup ].index_by(&:itself), prefix: true

  validates :message, presence: true, if: :kind_mention?
  validates :period_on, presence: true, if: :kind_daily_summary?
  validates :subject_user, presence: true, if: :kind_new_user_signup?
end
