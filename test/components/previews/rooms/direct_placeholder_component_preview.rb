class Rooms::DirectPlaceholderComponentPreview < ViewComponent::Preview
  def default
    render component("Maya Rivera")
  end

  def long_name
    render component("Alexandria Cassandra Montgomery")
  end

  private
    def component(name)
      user = User.new(id: 60_001, name: name, updated_at: Time.current).tap do |record|
        record.define_singleton_method(:persisted?) { true }
        record.define_singleton_method(:new_record?) { false }
      end

      Rooms::DirectPlaceholderComponent.new(
        user: user,
        url: "/rooms/directs?user_ids[]=#{user.id}",
        avatar_source: "default-avatar.svg"
      )
    end
end
