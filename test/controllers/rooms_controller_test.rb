require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "index redirects to the user's last room" do
    get rooms_url
    assert_redirected_to room_url(users(:david).rooms.last)
  end

  test "show" do
    room = users(:david).rooms.last
    get room_url(room)
    assert_response :success

    assert_select "aside#channels turbo-frame#user_sidebar[src='#{user_sidebar_path}']"
    assert_select "aside#sidebar .member-sidebar[aria-label='Community members']" do
      assert_select ".member-sidebar__group"
      assert_select "a.member-sidebar__member", count: room.users.active.count
      assert_select ".member-sidebar__role[aria-label='Administrator']", count: room.users.active.administrator.count
    end
    assert_select "#system_welcome", count: 0
    assert_select "nav#nav figure.account-logo", count: 0
    assert_select "nav#nav a[href='#{polymorphic_path([ :edit, room ])}']", text: "Settings for this #{room.direct? ? "Ping" : "room"}" do |links|
      assert_equal "direct_conversation_dialog", links.first["data-turbo-frame"] if room.direct?
    end
  end

  test "inaccessible room redirects to a persistent descriptive alert" do
    get room_url(rooms(:bender_and_kevin))

    assert_redirected_to root_url
    follow_redirect!
    follow_redirect!

    assert_response :success
    assert_select ".flash.flash--alert[role='alert']" do
      assert_select ".flash__message", text: "Room not found or inaccessible"
      assert_select "button[aria-label='Dismiss notification'][data-action='element-removal#remove']"
    end
  end

  test "configured closed stream renders above chat with a narrow frame CSP and no credentials" do
    configure_streaming
    room = rooms(:designers)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live", stream_title: "Town Hall")
    sign_in :jz

    get room_url(room)

    assert_response :success
    assert_select "body.sidebar.stream-room"
    assert_select "main > section.room-stream"
    assert_select "main > section.stream-description"
    assert_select ".room-stream__info > .stream-viewers"
    assert_select "main > turbo-cable-stream-source[channel='RoomPresenceChannel']", count: 1
    assert_select "aside#sidebar .member-sidebar", count: 0
    assert_select "iframe[src='https://stream.example.test/player']"
    assert_includes response.headers["Content-Security-Policy"], "frame-src 'self' https://stream.example.test"
    assert_no_match(/eyJ[a-zA-Z0-9_-]+\./, response.body)
    assert_no_match(/RTMP_HOMEBREW_PRIVATE_KEY/, response.body)
  end

  test "direct stream player uses narrow media CSP and keeps its iframe fallback out of the response" do
    configure_streaming
    Streaming::Configuration.stubs(:direct_player_enabled?).returns(true)
    room = rooms(:designers)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
    sign_in :jz

    get room_url(room)

    assert_response :success
    assert_select "media-player[data-room-stream-target='player']"
    assert_select "iframe", count: 0
    assert_includes response.headers["Content-Security-Policy"], "connect-src 'self' https://stream.example.test"
    assert_includes response.headers["Content-Security-Policy"], "media-src 'self' blob: https://stream.example.test"
    assert_no_match(/eyJ[a-zA-Z0-9_-]+\./, response.body)
  end

  test "configured stream renders its rich description and compact viewer menu" do
    configure_streaming
    room = rooms(:designers)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live",
      stream_description: "Every Friday at eight")
    memberships(:jz_designers).update!(connected_at: Time.current, connections: 1)
    sign_in :jz

    get room_url(room)

    assert_select ".stream-description .trix-content", text: /Every Friday at eight/
    assert_select "##{dom_id(room, :stream_viewers)} summary", text: /1 viewer/
    assert_select ".stream-viewers__popup a[href='#{user_path(users(:jz))}']", text: users(:jz).name
  end

  test "configured stream chat omits attachment and rich text controls" do
    configure_streaming
    room = rooms(:pets)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")

    get room_url(room)

    assert_response :success
    assert_select "form#composer[data-controller='composer']" do
      assert_select "input[type='file']", count: 0
      assert_select "[data-action='composer#toggleToolbar']", count: 0
    end
    assert_select "footer .composer a.composer__context-btn", count: 0
    composer = css_select("form#composer").sole
    refute_includes composer["data-action"], "composer#dropFiles"
    refute_includes composer["data-action"], "composer#pasteFiles"
  end

  test "disabled streams do not render a player" do
    configure_streaming
    get room_url(rooms(:watercooler))
    assert_select ".room-stream", count: 0

  end

  test "configured open stream renders for room members" do
    configure_streaming
    room = rooms(:pets)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "public/live")

    get room_url(room)

    assert_response :success
    assert_select ".room-stream iframe[src='https://stream.example.test/player']"
  end

  test "direct room member sidebar only shows its participants" do
    room = rooms(:david_and_jason)

    get room_url(room)

    room.users.active.each do |user|
      assert_select "aside#sidebar a.member-sidebar__member[href='#{user_path(user)}']", count: 1
    end
    assert_select "aside#sidebar a.member-sidebar__member", count: room.users.active.count
  end

  test "room settings control is only visible to administrators" do
    sign_in :jz
    room = users(:jz).rooms.last

    get room_url(room)

    assert_response :success
    assert_select "nav#nav a[href='#{polymorphic_path([ :edit, room ])}']", count: 0
  end

  test "notification bell preserves its frame and permission-controller contracts" do
    get room_url(rooms(:watercooler))

    assert_select "[data-controller~='notifications'][data-notifications-subscriptions-url-value]" do
      assert_select "turbo-frame##{dom_id(rooms(:watercooler), :involvement)}[data-controller='turbo-frame']" do
        assert_select "button[aria-label='Notification settings for this room'][data-notifications-target='bell']"
      end
      assert_select "dialog[data-notifications-target='notAllowedNotice']"
    end

    get room_url(rooms(:david_and_jason))
    assert_select "button[aria-label='Notification settings for this Ping']"
  end

  test "optimistic message template preserves the confirmed message shell contract" do
    get room_url(rooms(:watercooler))

    assert_select "script[type='text/template'][data-messages-target='template']", count: 1
    assert_includes response.body, 'id="message_$clientMessageId$"'
    assert_includes response.body, 'class="message message--me $messageClasses$"'
    assert_includes response.body, 'data-message-timestamp="$messageTimestamp$"'
    assert_includes response.body, 'data-messages-target="message"'
    assert_includes response.body, "$body$"
    assert_includes response.body, "message__actions"
    assert_includes response.body, "message__options-btn"
  end

  test "composer preserves its frame, form, Stimulus, attachment, and typing contracts" do
    room = rooms(:watercooler)

    get room_url(room)

    assert_select "footer .composer[data-controller='typing-notifications']" do
      assert_select "a.composer__context-btn[href='#{searches_path}']", text: "Search"
      assert_select "turbo-frame#composer-frame" do
        assert_select "form#composer[action='#{room_messages_path(room)}']" \
                      "[data-controller='composer drop-target']" \
                      "[data-composer-messages-outlet='#message-area']" \
                      "[data-composer-room-id-value='#{room.id}']"
        assert_select "fieldset[data-composer-target='fields']"
        assert_select "[data-composer-target='fileList']"
        assert_select "trix-editor[aria-label='Write a message'][data-composer-target='text']" \
                      "[data-controller='rich-autocomplete']" \
                      "[data-rich-autocomplete-url-value='#{autocompletable_users_path(room_id: room.id)}']" \
                      "[data-rich-autocomplete-rooms-url-value='#{autocompletable_rooms_path(room_id: room.id)}']"
        assert_select "input[type='file'][multiple][data-action='composer#filePicked']"
        assert_select "button[type='button'][data-action='composer#toggleToolbar']", text: "Rich text"
        assert_select "button[type='submit'][data-action='composer#submit']", text: "Send Message"
        assert_select "input[type='hidden'][data-composer-target='clientid']", visible: false
      end
      assert_select "[data-typing-notifications-target='indicator'] [data-typing-notifications-target='author']"
    end

    composer = css_select("form#composer").sole
    actions = composer["data-action"]
    %w[
      drop-target:drop@window->composer#dropFiles
      trix-file-accept->composer#preventAttachment
      paste->composer#pasteFiles
      turbo:submit-end->composer#submitEnd
      refresh-room:online@window->composer#online
      refresh-room:offline@window->composer#offline
      typing-notifications#stop
    ].each { |action| assert_includes actions, action }
  end

  test "shows records the last room visited in a cookie" do
    get room_url(users(:david).rooms.last)
    assert response.cookies[:last_room] = users(:david).rooms.last.id
  end

  test "destroy" do
    room = rooms(:designers)

    assert_turbo_stream_broadcasts :rooms, count: 1 do
      assert_difference -> { Room.count }, -1 do
        delete room_url(room)
      end
    end

    assert_rendered_turbo_stream_broadcast :rooms,
      action: "remove", target: [ room, :list ]
  end

  test "destroy only allowed for creators or those who can administer" do
    sign_in :jz

    assert_no_difference -> { Room.count } do
      delete room_url(rooms(:designers))
      assert_response :forbidden
    end

    rooms(:designers).update! creator: users(:jz)

    assert_difference -> { Room.count }, -1 do
      delete room_url(rooms(:designers))
    end
  end
end
