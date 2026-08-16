require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.bonfire.test"

    sign_in :david
    @room = rooms(:watercooler)
    @messages = @room.messages.ordered.to_a
  end

  test "index returns the last page by default" do
    get room_messages_url(@room)

    assert_response :success
    ensure_messages_present @messages.last
    assert_message_dom_contract @messages.last
  end

  test "index returns a page before the specified message" do
    get room_messages_url(@room, before: @messages.third)

    assert_response :success
    ensure_messages_present @messages.first, @messages.second
    ensure_messages_not_present @messages.third, @messages.fourth, @messages.fifth
  end

  test "index returns a page after the specified message" do
    get room_messages_url(@room, after: @messages.third)

    assert_response :success
    ensure_messages_present @messages.fourth, @messages.fifth
    ensure_messages_not_present @messages.first, @messages.second, @messages.third
  end

  test "index returns no_content when there are no messages" do
    @room.messages.destroy_all

    get room_messages_url(@room)

    assert_response :no_content
  end

  test "get renders a single message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    get room_message_url(@room, message)

    assert_response :success
  end

  test "creating a message broadcasts the message to the room" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "New one", client_message_id: 999 } }

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "append", target: [ @room, :messages ] do
      assert_message_dom_contract Message.last
      assert_select ".message__body", text: /New one/
      assert_copy_link_button room_at_message_url(@room, Message.last, host: "once.bonfire.test")
    end
  end

  test "initial and broadcast rendering use the client message id as the same outer identity" do
    post room_messages_url(@room, format: :turbo_stream), params: {
      message: { body: "Stable identity", client_message_id: "client-generated-42" }
    }

    message = Message.last
    assert_equal "message_client-generated-42", dom_id(message)

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "append", target: [ @room, :messages ] do
      assert_select "#message_client-generated-42[data-message-id='#{message.id}']"
    end

    get room_messages_url(@room)
    assert_select "#message_client-generated-42[data-message-id='#{message.id}']"
  end

  test "creating a message broadcasts unread room to each member" do
    @room.users.each do |member|
      assert_broadcasts UnreadRoomsChannel.stream_name_for(member.id), 1 do
        post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "New one #{member.id}", client_message_id: member.id } }
      end
    end
  end

  test "creating a message doesn't broadcast unread room to non-members" do
    outsiders = User.where.not(id: @room.users.map(&:id))
    assert outsiders.any?, "need someone outside the room for this test to mean anything"

    outsiders.each do |outsider|
      assert_no_broadcasts UnreadRoomsChannel.stream_name_for(outsider.id) do
        post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "New one", client_message_id: 999 } }
      end
    end
  end

  test "creating in a deleted or inaccessible room replaces the composer frame" do
    post room_messages_url("missing-room", format: :turbo_stream), params: {
      message: { body: "Cannot be delivered", client_message_id: "missing-room-message" }
    }

    assert_response :success
    assert_select "turbo-frame#composer-frame" do
      assert_select ".composer__input.txt-negative", text: "This room was deleted."
    end
    assert_no_turbo_stream_broadcasts "missing-room"
  end

  test "update updates a message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    put room_message_url(@room, message), params: { message: { body: "Updated body" } }

    assert_redirected_to room_message_url(@room, message)
    assert_equal "Updated body", message.reload.plain_text_body
    assert_rendered_turbo_stream_broadcast @room, :messages,
      action: "replace", target: [ message, :presentation ] do
      assert_select "##{dom_id(message, :presentation)}[data-reply-target='body'][data-messages-target='body']", text: /Updated body/
    end
  end

  test "admin updates a message belonging to another user" do
    message = @room.messages.where(creator: users(:jason)).first

    Turbo::StreamsChannel.expects(:broadcast_replace_to).once
    put room_message_url(@room, message), params: { message: { body: "Updated body" } }

    assert_redirected_to room_message_url(@room, message)
    assert_equal "Updated body", message.reload.plain_text_body
  end

  test "stream chat messages cannot be edited or updated" do
    configure_streaming
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
    message = @room.messages.where(creator: users(:david)).first
    original_body = message.plain_text_body

    get edit_room_message_url(@room, message)
    assert_response :forbidden

    put room_message_url(@room, message), params: { message: { body: "Updated body" } }
    assert_response :forbidden
    assert_equal original_body, message.reload.plain_text_body
  end

  test "only administrators can delete stream chat messages" do
    configure_streaming
    @room = rooms(:designers)
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
    message = @room.messages.where(creator: users(:jason)).first

    sign_in :jz
    delete room_message_url(@room, message, format: :turbo_stream)
    assert_response :forbidden
    assert Message.exists?(message.id)

    sign_in :david
    assert users(:david).administrator?
    assert_difference -> { Message.count }, -1 do
      delete room_message_url(@room, message, format: :turbo_stream)
      assert_response :success
    end
  end

  test "destroy destroys a message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    assert_difference -> { Message.count }, -1 do
      delete room_message_url(@room, message, format: :turbo_stream)
      assert_response :success
    end

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "remove", target: message
  end

  test "admin destroy destroys a message belonging to another user" do
    assert users(:david).administrator?
    message = @room.messages.where(creator: users(:jason)).first

    assert_difference -> { Message.count }, -1 do
      Turbo::StreamsChannel.expects(:broadcast_remove_to).once
      delete room_message_url(@room, message, format: :turbo_stream)
      assert_response :success
    end
  end

  test "ensure non-admin can't update a message belonging to another user" do
    sign_in :jz
    assert_not users(:jz).administrator?

    room = rooms(:designers)
    message = room.messages.where(creator: users(:jason)).first

    put room_message_url(room, message), params: { message: { body: "Updated body" } }
    assert_response :forbidden
  end

  test "ensure non-admin can't destroy a message belonging to another user" do
    sign_in :jz
    assert_not users(:jz).administrator?

    room = rooms(:designers)
    message = room.messages.where(creator: users(:jason)).first

    delete room_message_url(room, message, format: :turbo_stream)
    assert_response :forbidden
  end

  test "mentioning a bot triggers a webhook" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200)

    assert_enqueued_jobs 1, only: Bot::WebhookJob do
      post room_messages_url(@room, format: :turbo_stream), params: { message: {
        body: "<div>Hey #{mention_attachment_for(:bender)}</div>", client_message_id: 999 } }
    end
  end

  private
    def assert_message_dom_contract(message)
      assert_select "##{dom_id(message)}.message[data-controller~='reply']" \
                    "[data-user-id='#{message.creator_id}'][data-message-id='#{message.id}']" \
                    "[data-message-timestamp][data-message-updated-at][data-sort-value]" \
                    "[data-messages-target~='message'][data-search-results-target~='message']" \
                    "[data-refresh-room-target~='message'][data-reply-composer-outlet='#composer']" do
        assert_select "turbo-frame##{dom_id(message, :edit)}"
        assert_select "##{dom_id(message, :presentation)}[data-reply-target='body'][data-messages-target='body']"
        assert_select ".message__actions[data-controller~='soft-keyboard']"
        assert_select "details[data-controller~='popup'] [data-popup-target='menu']"
        assert_select "turbo-frame##{dom_id(message, :boosting)}"
        assert_select "turbo-frame##{dom_id(message, :new_boost)}"
      end
    end

    def ensure_messages_present(*messages, count: 1)
      messages.each do |message|
        assert_select "#" + dom_id(message), count:
      end
    end

    def ensure_messages_not_present(*messages)
      ensure_messages_present *messages, count: 0
    end

    def assert_copy_link_button(url)
      assert_select ".btn[title='Copy link'][data-copy-to-clipboard-content-value='#{url}']"
    end
end
