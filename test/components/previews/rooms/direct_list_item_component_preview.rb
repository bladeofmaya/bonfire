class Rooms::DirectListItemComponentPreview < ViewComponent::Preview
  def default
    render component([ preview_user(20_001, "Maya Rivera") ])
  end

  def unread
    render component([ preview_user(20_001, "Maya Rivera") ], unread_count: 3)
  end

  def selected
    render component([ preview_user(20_001, "Maya Rivera") ], selected: true)
  end

  def group
    render component([
      preview_user(20_001, "Maya Rivera"),
      preview_user(20_002, "Alex Chen"),
      preview_user(20_003, "Samira Okafor"),
      preview_user(20_004, "Noah Williams"),
      preview_user(20_005, "Ava Müller")
    ])
  end

  def long_names
    render component([
      preview_user(20_001, "Alexandria Cassandra Montgomery"),
      preview_user(20_002, "Maximiliano Sebastián Fernández")
    ])
  end

  private
    def component(participants, unread_count: 0, selected: false)
      room = Rooms::Direct.new(id: 20_001, updated_at: Time.current).tap do |record|
        record.define_singleton_method(:persisted?) { true }
      end

      Rooms::DirectListItemComponent.new(
        room: room, participants: participants, unread_count: unread_count, selected: selected, sort_timestamp: room.updated_at,
        avatar_source: "default-avatar.svg"
      )
    end

    def preview_user(id, name)
      User.new(id: id, name: name, updated_at: Time.current).tap do |user|
        user.define_singleton_method(:persisted?) { true }
        user.define_singleton_method(:new_record?) { false }
      end
    end
end
