require "test_helper"

class Room::DirectConversationTest < ActiveSupport::TestCase
  test "a new ping restores a hidden recipient and increments their unread count" do
    room = rooms(:david_and_jason)
    recipient = memberships(:david_david_and_jason)
    recipient.update!(involvement: :invisible, unread_at: nil, unread_count: 0, connected_at: nil)

    room.messages.create!(creator: users(:jason), body: "Are you there?")

    assert recipient.reload.involved_in_everything?
    assert recipient.unread?
    assert_equal 1, recipient.unread_count
  end

  test "successive unread messages increment the count" do
    room = rooms(:david_and_jason)
    recipient = memberships(:david_david_and_jason)
    recipient.update!(unread_at: nil, unread_count: 0, connected_at: nil)

    2.times { room.messages.create!(creator: users(:jason), body: "Ping") }

    assert_equal 2, recipient.reload.unread_count
  end
end
