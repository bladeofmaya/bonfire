require "test_helper"

class Rooms::OpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show redirects to get general show" do
    get rooms_open_url(users(:david).rooms.opens.last)
    assert_redirected_to room_url(users(:david).rooms.opens.last)
  end

  test "new" do
    get new_rooms_open_url
    assert_response :success
  end

  test "edit uses the tabbed room settings layout" do
    get edit_rooms_open_url(rooms(:pets))

    assert_response :success
    assert_select ".room-settings button[role='tab']", count: 3
    assert_select "button[data-profile-tabs-name='general']", text: "General"
    assert_select "button[data-profile-tabs-name='permissions']", text: "Permissions"
    assert_select "button[data-profile-tabs-name='streaming']", text: "Streaming"
    assert_select "#room-panel-streaming form[action='#{room_stream_path(rooms(:pets))}']"
  end

  test "create" do
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 2 do
      post rooms_opens_url, params: { room: { name: "My New Room" } }
    end

    assert_equal Room.last.memberships.count, User.count
    assert_redirected_to room_url(Room.last)

    room = Room.last
    assert_rendered_turbo_stream_broadcast users(:david), :rooms, action: "prepend", target: :shared_rooms do
      assert_select "##{dom_id(room, :list)}[data-room-id='#{room.id}'][data-sorted-list-name='My New Room']"
    end
  end

  test "create forbidden by non-admin when account restricts creation to admins" do
    accounts(:signal).settings.restrict_room_creation_to_administrators = true
    accounts(:signal).save!

    sign_in :jz
    post rooms_opens_url, params: { room: { name: "My New Room" } }
    assert_response :forbidden
  end

  test "only admins or creators can update" do
    sign_in :jz

    assert_turbo_stream_broadcasts :rooms, count: 0 do
      put rooms_open_url(rooms(:hq)), params: { room: { name: "New Name" } }
    end

    assert_response :forbidden
    assert rooms(:hq).reload.name, "HQ"
  end

  test "update" do
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 1 do
      put rooms_open_url(rooms(:pets)), params: { room: { name: "New Name" } }
    end

    assert_redirected_to room_url(rooms(:pets))
    assert rooms(:pets).reload.name, "New Name"

    assert_rendered_turbo_stream_broadcast users(:david), :rooms,
      action: "replace", target: [ rooms(:pets), :list ] do
      assert_select "##{dom_id(rooms(:pets), :list)}[data-sorted-list-name='New Name']", text: "New Name"
    end
  end

  test "update a closed room to be open" do
    put rooms_open_url(rooms(:designers)), params: { room: { name: "Doesn't matter" } }
    assert_equal rooms(:designers).memberships.count, User.count
  end

  test "a direct room can't be promoted to open by its creator" do
    sign_in :kevin
    direct = rooms(:bender_and_kevin)

    put rooms_open_url(direct), params: { room: { name: "Watercooler" } }

    assert_equal "Rooms::Direct", Room.find(direct.id).type
    assert_equal [ users(:bender).id, users(:kevin).id ].sort, Room.find(direct.id).user_ids.sort
  end

  test "a direct room can't be promoted to open by an administrator either" do
    direct = rooms(:david_and_kevin)

    put rooms_open_url(direct), params: { room: { name: "Watercooler" } }

    assert_equal "Rooms::Direct", Room.find(direct.id).type
    assert_equal [ users(:david).id, users(:kevin).id ].sort, Room.find(direct.id).user_ids.sort
  end
end
