require "application_system_test_case"

class UnreadRoomsTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
  end

  test "sending messages between two users" do
    designers_room = rooms(:designers)
    hq_room = rooms(:hq)

    join_room hq_room
    assert_room_read hq_room

    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room designers_room
      send_message("Hello!!")
      send_message("Talking to myself?")
    end

    assert_room_unread designers_room

    join_room designers_room
    assert_room_read designers_room
  end

  test "channel mention badges update live and clear when the room is read" do
    designers_room = rooms(:designers)
    join_room rooms(:hq)
    memberships(:jz_designers).update!(connected_at: nil, connections: 0)

    message = designers_room.messages.create!(
      body: "Hello #{mention_attachment_for(:jz)}",
      creator: users(:david),
      client_message_id: "sidebar-mention"
    )
    assert_equal 1, memberships(:jz_designers).reload.unread_mention_count
    message.broadcast_create

    within "##{dom_id(designers_room, :list)}" do
      assert_selector "a.unread .channel__mention-count", text: "1"
    end

    join_room designers_room
    within "##{dom_id(designers_room, :list)}" do
      assert_no_selector "a.unread"
      assert_no_selector ".channel__mention-count", visible: :visible
    end
  end
end
