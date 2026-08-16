class Messages::ActionMenuComponent < ApplicationComponent
  attr_reader :message, :permalink_url

  def initialize(message:, permalink_url:)
    @message = message
    @permalink_url = permalink_url
  end

  def attachment?
    message.content_type.attachment?
  end

  def editable?
    !stream_chat?
  end

  def stream_chat?
    message.room.stream_configured?
  end
end
