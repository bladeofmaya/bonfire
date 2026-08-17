class Account < ApplicationRecord
  include Joinable

  has_rich_text :readme
  has_many :custom_emotes, dependent: :destroy

  has_one_attached :logo do |attachable|
    attachable.variant :large, resize_to_limit: [ 512, 512 ], format: :png
    attachable.variant :small, resize_to_limit: [ 192, 192 ], format: :png
  end

  has_json :settings, restrict_room_creation_to_administrators: false

  def readme?
    readme.to_plain_text.present?
  end

  def publish_readme!(content)
    next_digest = readme_content_digest(content)
    return if next_digest == readme_digest

    transaction do
      update!(readme: content)
      update_columns(
        readme_version: readme_version + 1,
        readme_digest: next_digest,
        readme_published_at: next_digest.present? ? Time.current : nil,
        updated_at: Time.current
      )
    end
  end

  def logo_variant(size)
    logo.variant(size).processed if logo.variable?
  end

  def active_custom_emotes
    @active_custom_emotes ||= custom_emotes.active.with_attached_image.ordered.load
  end

  private
    def readme_content_digest(content)
      action_text = ActionText::Content.new(content.to_s)
      Digest::SHA256.hexdigest(action_text.to_html) if action_text.to_plain_text.strip.present?
    end
end
