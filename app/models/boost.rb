class Boost < ApplicationRecord
  belongs_to :message, touch: true
  belongs_to :booster, class_name: "User", default: -> { Current.user }
  belongs_to :custom_emote, optional: true

  scope :ordered, -> { order(:created_at) }
end
