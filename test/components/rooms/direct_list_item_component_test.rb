require "test_helper"

class Rooms::DirectListItemComponentTest < ComponentTestCase
  test "preserves the direct-room DOM, sorting, and unread contracts" do
    membership = memberships(:david_david_and_jason)
    participant = users(:jason)

    render_inline component(membership, participants: [ participant ], unread: true)

    assert_component_root "a##{dom_id(membership.room, :list)}.direct.unread"
    assert_selector "[data-room-id='#{membership.room.id}'][data-sorted-list-number='#{membership.room.updated_at.to_fs(:epoch)}']"
    assert_selector "[data-rooms-list-target='room'][data-badge-dot-target='unread'][data-sorted-list-target='item']"
    assert_selector ".avatar img[aria-hidden='true'][src='#{avatar_path(participant)}']"
    assert_selector ".for-screen-reader", text: "Ping with #{participant.name}"
  end

  test "renders grouped participants with full accessible names and abbreviated visible names" do
    membership = memberships(:david_david_and_jason)
    participants = users(:jason, :kevin, :jz, :bender)

    render_inline component(membership, participants: participants)

    assert_selector ".avatar__group .avatar", count: 4
    assert_selector ".for-screen-reader", text: "Ping with #{participants.map(&:name).to_sentence}"
    assert_selector ".direct__author [aria-hidden='true']", text: component(membership, participants: participants).abbreviated_names
  end

  test "renders the viewing user fallback supplied for a self-only conversation" do
    membership = memberships(:david_david_and_jason)

    render_inline component(membership, participants: [ membership.user ])

    assert_selector ".for-screen-reader", text: "Ping with #{membership.user.name}"
    assert_selector ".avatar img[src='#{avatar_path(membership.user)}']"
  end

  test "adapter cache key changes with membership, room, and participant records" do
    membership = memberships(:david_david_and_jason)
    participant = users(:jason)
    original_key = expanded_cache_key(membership, participant)

    participant.touch
    refute_equal original_key, expanded_cache_key(membership, participant)

    participant_key = expanded_cache_key(membership, participant)
    membership.room.touch
    refute_equal participant_key, expanded_cache_key(membership, participant)

    room_key = expanded_cache_key(membership, participant)
    membership.touch
    refute_equal room_key, expanded_cache_key(membership, participant)
  end

  test "renders through the production partial adapter in a Turbo broadcast" do
    membership = memberships(:david_david_and_jason)
    participant = users(:jason)

    streams = capture_turbo_stream_broadcasts(:production_direct_rooms) do
      membership.broadcast_prepend_to :production_direct_rooms, target: :direct_rooms,
        partial: "users/sidebars/rooms/direct", locals: { participants: [ participant ] }
    end

    stream = streams.sole
    assert_equal "prepend", stream["action"]
    assert_equal "direct_rooms", stream["target"]
    assert stream.at_css("template a.direct[data-room-id='#{membership.room.id}']")
  end

  private
    def component(membership, participants:, unread: false)
      Rooms::DirectListItemComponent.new(
        room: membership.room,
        participants: participants,
        unread: unread,
        sort_timestamp: membership.room.updated_at
      )
    end

    def expanded_cache_key(membership, participant)
      ActiveSupport::Cache.expand_cache_key([ membership, membership.room, participant ])
    end

    def avatar_path(user)
      Rails.application.routes.url_helpers.user_avatar_path(
        user.avatar_token, v: user.updated_at.to_fs(:number)
      )
    end
end
