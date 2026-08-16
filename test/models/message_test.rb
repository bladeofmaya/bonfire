require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper, ActiveJob::TestHelper

  test "creating a message enqueues to push later" do
    assert_enqueued_jobs 1, only: [ Room::PushMessageJob ] do
      create_new_message_in rooms(:designers)
    end
  end

  test "all emoji" do
    assert Message.new(body: "😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "Haha! 😄🤘").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥\nmultiple lines\n💯").plain_text_body.all_emoji?
    assert_not Message.new(body: "🔥 💯").plain_text_body.all_emoji?
  end

  test "mentionees" do
    message = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_with_duplicate_mentions = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)} #{mention_attachment_for(:david)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [ users(:david) ], message.mentionees

    message_mentioning_a_non_member = Message.new room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:kevin)}</div>", creator: users(:jason), client_message_id: "earth"
    assert_equal [], message_mentioning_a_non_member.mentionees
  end

  test "unread mention counts are separate from total unread messages and clear on read" do
    membership = memberships(:david_watercooler)
    membership.update!(connected_at: nil, connections: 0, unread_at: nil, unread_count: 0, unread_mention_count: 0)

    rooms(:watercooler).messages.create!(
      body: "Hello", creator: users(:jason), client_message_id: "not-a-mention"
    )
    assert_equal 1, membership.reload.unread_count
    assert_equal 0, membership.unread_mention_count

    rooms(:watercooler).messages.create!(
      body: "Hello #{mention_attachment_for(:david)}", creator: users(:jason), client_message_id: "mention"
    )
    assert_equal 2, membership.reload.unread_count
    assert_equal 1, membership.unread_mention_count

    membership.read
    assert_equal 0, membership.unread_count
    assert_equal 0, membership.unread_mention_count
  end

  private
    def create_new_message_in(room)
      room.messages.create!(creator: users(:jason), body: "Hello", client_message_id: "123")
    end
end
