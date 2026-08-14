require "test_helper"

class Rooms::DirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "create" do
    post rooms_directs_url, params: { room: { name: "Launch crew" }, user_ids: [ users(:jz).id ] }

    room = Room.last
    assert_redirected_to room_url(room)
    assert room.users.include?(users(:david))
    assert room.users.include?(users(:jz))
    assert_equal "Launch crew", room.name

    room.memberships.each do |membership|
      assert_rendered_turbo_stream_broadcast membership.user, :rooms,
        action: "prepend", target: :direct_rooms do
        assert_select "##{dom_id(room, :list)}.direct-message-row[data-sorted-list-number] a.direct[data-room-id='#{room.id}']"
        assert_select ".for-screen-reader", text: /Ping with/
      end
    end
  end

  test "new renders a dialog with an optional name and multi-user selection" do
    get new_rooms_direct_url

    assert_response :success
    assert_select "turbo-frame#direct_conversation_dialog[target='_top']" do
      assert_select "dialog.direct-conversation-dialog[data-controller='dialog'][data-action='close->dialog#clear']"
      assert_select "form[data-turbo-frame='_top']"
      assert_select "input[data-dialog-target='autofocus']"
      assert_select "input[name='room[name]'][placeholder*='Friday stream planning']"
      assert_select "input[type='checkbox'][name='user_ids[]']", count: User.active.where.not(id: users(:david).id).count
      assert_select ".direct-conversation-dialog__member .switch > input.switch__input + .switch__btn",
        count: User.active.where.not(id: users(:david).id).count
    end
  end

  test "create requires at least one other participant" do
    assert_no_difference -> { Room.count } do
      post rooms_directs_url, params: { room: { name: "Empty ping" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: "Choose at least one person to ping."
  end

  test "creating for an existing participant set does not rename it" do
    room = rooms(:david_and_jason)

    assert_no_difference -> { Room.count } do
      post rooms_directs_url, params: { room: { name: "Boss fight" }, user_ids: [ users(:jason).id ] }
    end

    assert_nil room.reload.name
  end

  test "edit renders the reusable dialog with read-only participants" do
    room = rooms(:david_and_jason)
    room.update!(name: "Planning crew")

    get edit_rooms_direct_url(room)

    assert_response :success
    assert_select "turbo-frame#direct_conversation_dialog[target='_top']" do
      assert_select "dialog.direct-conversation-dialog[data-controller='dialog'][data-action='close->dialog#clear']"
      assert_select "form[data-turbo-frame='_top']"
      assert_select "input[data-dialog-target='autofocus']"
      assert_select "h2", text: "Edit Ping"
      assert_select "input[name='room[name]'][value='#{room.name}']"
      assert_select ".direct-conversation-dialog__member", count: room.users.active.count
      assert_select "input[name='user_ids[]']", count: 0
    end
  end

  test "update changes only the conversation name and broadcasts the sidebar replacement" do
    room = rooms(:david_and_jason)
    original_user_ids = room.user_ids.sort

    patch rooms_direct_url(room), params: { room: { name: "Night crew" }, user_ids: [ users(:jz).id ] }

    assert_redirected_to room_url(room)
    assert_equal "Night crew", room.reload.name
    assert_equal original_user_ids, room.user_ids.sort
    room.memberships.visible.each do |membership|
      assert_rendered_turbo_stream_broadcast membership.user, :rooms,
        action: "replace", target: dom_id(room, :list)
    end
  end

  test "members cannot access or update ping settings directly" do
    sign_in :kevin
    room = rooms(:david_and_kevin)

    get edit_rooms_direct_url(room)
    assert_response :forbidden

    patch rooms_direct_url(room), params: { room: { name: "Leaked rename" } }
    assert_response :forbidden
    refute_equal "Leaked rename", room.reload.name
  end

  test "create only once per user set" do
    assert_difference -> { Room.all.count }, +1 do
      post rooms_directs_url, params: { user_ids: [ users(:jz).id ] }
      post rooms_directs_url, params: { user_ids: [ users(:jz).id ] }
    end
  end

  test "create restores a direct conversation hidden by the current user" do
    room = rooms(:david_and_jason)
    membership = memberships(:david_david_and_jason)
    membership.update!(involvement: :invisible)

    post rooms_directs_url, params: { user_ids: [ users(:jason).id ] }

    assert_redirected_to room_url(room)
    assert membership.reload.involved_in_everything?
  end

  test "members cannot destroy a direct room" do
    sign_in :kevin

    assert_no_difference -> { Room.count } do
      delete rooms_direct_url(rooms(:david_and_kevin))
      assert_response :forbidden
    end
  end

  test "administrators can destroy a direct room" do
    assert_difference -> { Room.count }, -1 do
      delete rooms_direct_url(rooms(:david_and_jason))
      assert_redirected_to root_url
    end
  end

  test "destroy can't reach a closed room the member didn't create" do
    sign_in :kevin

    assert_no_difference -> { Room.count } do
      delete rooms_direct_url(rooms(:designers))
    end

    assert rooms(:designers).reload.persisted?
  end

  test "destroy can't reach an open room the member didn't create" do
    sign_in :kevin

    assert_no_difference -> { Room.count } do
      delete rooms_direct_url(rooms(:hq))
    end

    assert rooms(:hq).reload.persisted?
  end

  test "destroy can't reach a room the member isn't in at all" do
    sign_in :jz

    assert_no_difference -> { Room.count } do
      delete rooms_direct_url(rooms(:david_and_kevin))
    end

    assert rooms(:david_and_kevin).reload.persisted?
  end
end
