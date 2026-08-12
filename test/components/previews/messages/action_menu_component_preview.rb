class Messages::ActionMenuComponentPreview < ViewComponent::Preview
  def text
    render Messages::ActionMenuComponent.new(
      message: preview_message,
      permalink_url: "/rooms/30_001/at/preview-message"
    )
  end

  private
    def preview_message
      room = Rooms::Open.new(id: 30_001, name: "Announcements").tap do |record|
        record.define_singleton_method(:persisted?) { true }
      end

      Message.new(id: 30_001, room: room, client_message_id: "preview-message").tap do |message|
        message.define_singleton_method(:persisted?) { true }
        message.define_singleton_method(:content_type) { "text".inquiry }
      end
    end
end
