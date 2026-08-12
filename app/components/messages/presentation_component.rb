class Messages::PresentationComponent < ApplicationComponent
  attr_reader :message

  def initialize(message:)
    @message = message
  end
end
