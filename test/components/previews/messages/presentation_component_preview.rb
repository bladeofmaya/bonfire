class Messages::PresentationComponentPreview < ViewComponent::Preview
  def text
    render component("A regular Bonfire message with a link to https://example.com.")
  end

  def rich_text
    render component("<strong>Important:</strong> community announcements belong here.")
  end

  def sound
    render component("/play bell")
  end

  private
    def component(body)
      room = Rooms::Open.new(id: 50_001, name: "Announcements")
      message = Message.new(
        id: 50_001,
        room: room,
        creator: User.new(id: 50_001, name: "Maya Rivera", updated_at: Time.current),
        client_message_id: "preview-message",
        body: body
      )

      [ room, message, message.creator ].each do |record|
        record.define_singleton_method(:persisted?) { true }
        record.define_singleton_method(:new_record?) { false }
      end

      Messages::PresentationComponent.new(message: message)
    end
end
