class CustomEmote < ApplicationRecord
  include ActionText::Attachable

  SHORTCODE_PATTERN = /\A[a-z0-9][a-z0-9_-]{1,31}\z/
  ALLOWED_CONTENT_TYPES = %w[ image/png image/gif image/webp ].freeze
  MAX_FILE_SIZE = 1.megabyte

  belongs_to :account
  has_one_attached :image
  has_many :boosts, dependent: :restrict_with_error

  scope :active, -> { where(disabled_at: nil) }
  scope :ordered, -> { order(:shortcode) }

  before_validation { self.shortcode = shortcode.to_s.strip.downcase }

  validates :shortcode, presence: true, format: { with: SHORTCODE_PATTERN },
    uniqueness: { scope: :account_id, case_sensitive: false }
  validate :acceptable_image

  def disable!
    update!(disabled_at: Time.current)
  end

  def to_attachable_partial_path
    "custom_emotes/custom_emote"
  end

  def to_trix_content_attachment_partial_path
    to_attachable_partial_path
  end

  def attachable_plain_text_representation(_caption)
    ":#{shortcode}:"
  end

  private
    def acceptable_image
      errors.add(:image, "must be attached") unless image.attached?
      return unless image.attached?

      errors.add(:image, "must be a PNG, GIF, or WebP image") unless image.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:image, "must be smaller than 1 MB") if image.byte_size > MAX_FILE_SIZE
    end
end
