class Messages::ActionMenuComponent < ApplicationComponent
  attr_reader :message, :permalink_url

  def initialize(message:, permalink_url:)
    @message = message
    @permalink_url = permalink_url
  end

  def attachment?
    message.content_type.attachment?
  end
end
