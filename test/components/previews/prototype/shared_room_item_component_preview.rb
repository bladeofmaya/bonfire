class Prototype::SharedRoomItemComponentPreview < ViewComponent::Preview
  def normal
    render Prototype::SharedRoomItemComponent.new(room: preview_room("Announcements"))
  end

  def unread
    render Prototype::SharedRoomItemComponent.new(room: preview_room("Announcements"), unread: true)
  end

  def long_text
    render Prototype::SharedRoomItemComponent.new(room: preview_room("Announcements and important community updates from the team"))
  end

  private
    def preview_room(name)
      Rooms::Open.new(id: 10_001, name: name).tap do |room|
        room.define_singleton_method(:persisted?) { true }
      end
    end
end
