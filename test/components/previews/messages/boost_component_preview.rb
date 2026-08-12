class Messages::BoostComponentPreview < ViewComponent::Preview
  def text
    render component("Thoughtful point")
  end

  def emoji
    render component("🔥")
  end

  def long_text
    render component("This is a longer custom reaction that exercises the available inline space")
  end

  private
    def component(content)
      Messages::BoostComponent.new(boost: preview_boost(content), avatar_source: "default-avatar.svg")
    end

    def preview_boost(content)
      room = Rooms::Open.new(id: 40_001, name: "Announcements")
      message = Message.new(id: 40_001, client_message_id: "preview-message", room: room)
      booster = User.new(id: 40_001, name: "Maya Rivera", updated_at: Time.current)

      Boost.new(id: 40_001, message: message, booster: booster, content: content).tap do |boost|
        [ room, message, booster, boost ].each do |record|
          record.define_singleton_method(:persisted?) { true }
          record.define_singleton_method(:new_record?) { false }
        end
      end
    end
end
