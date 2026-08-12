class Rooms::SharedListItemComponentPreview < ViewComponent::Preview
  def default
    render component("Announcements")
  end

  def unread
    render component("Announcements", unread: true)
  end

  def long_name
    render component("Announcements and important community updates from the team")
  end

  private
    def component(name, unread: false)
      room = Rooms::Open.new(id: 10_001, name: name).tap do |record|
        record.define_singleton_method(:persisted?) { true }
      end

      Rooms::SharedListItemComponent.new(room: room, sort_key: room.name, unread: unread)
    end
end
