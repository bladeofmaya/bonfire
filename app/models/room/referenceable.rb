module Room::Referenceable
  extend ActiveSupport::Concern
  include ActionText::Attachable

  def to_attachable_partial_path
    "rooms/channel_references/#{model_name.element}"
  end

  def to_trix_content_attachment_partial_path
    to_attachable_partial_path
  end

  def attachable_plain_text_representation(caption)
    name
  end
end
