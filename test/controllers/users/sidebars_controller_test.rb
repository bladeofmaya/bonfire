require "test_helper"

class Users::SidebarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get user_sidebar_url

    assert_select "turbo-frame#user_sidebar[data-turbo-permanent][target='_top']" \
                  "[data-controller='rooms-list read-rooms turbo-frame']"
    assert_select "#shared_rooms[data-controller='sorted-list']"
    assert_select "#direct_rooms[data-controller='sorted-list']" \
                  "[data-action='rooms-list:unread@window->sorted-list#updateItem']"

    users(:david).rooms.opens.each do |room|
      assert_select "a##{dom_id(room, :list)}.room[data-room-id='#{room.id}'][data-sorted-list-name='#{room.name}']", text: room.name
    end
  end

  test "subscribes to global and user-specific room updates and preserves shell controls" do
    get user_sidebar_url

    assert_select "turbo-frame#user_sidebar" do
      assert_select "turbo-cable-stream-source", count: 2
      assert_select "button.btn--icon.sidebar__toggle[data-action='toggle-class#toggle']", text: "Open menu"
    end

    assert_select "a.sidebar__tool[href='#{user_profile_path}']", text: "My Settings"
    assert_select "a.sidebar__tool[href='#{edit_account_path}']", text: "Account Settings"
  end

  test "shows room creation to administrators when creation is restricted" do
    accounts(:signal).update!(settings: { restrict_room_creation_to_administrators: true })

    get user_sidebar_url

    assert_select "a.rooms__new-btn[href='#{new_rooms_open_path}'][aria-label='New Chat Room']"
  end

  test "hides restricted room creation from members" do
    accounts(:signal).update!(settings: { restrict_room_creation_to_administrators: true })
    sign_in :jz

    get user_sidebar_url

    assert_select "a.rooms__new-btn", count: 0
  end

  test "shows unrestricted room creation to members" do
    accounts(:signal).update!(settings: { restrict_room_creation_to_administrators: false })
    sign_in :jz

    get user_sidebar_url

    assert_select "a.rooms__new-btn[href='#{new_rooms_open_path}'][aria-label='New Chat Room']"
  end

  test "initial shared and direct items expose their distinct sorting contracts" do
    get user_sidebar_url

    shared_names = css_select("#shared_rooms [data-sorted-list-name]").map { |item| item["data-sorted-list-name"] }
    assert_equal shared_names.sort_by(&:downcase), shared_names

    direct_numbers = css_select("#direct_rooms [data-sorted-list-number]").map { |item| item["data-sorted-list-number"].to_i }
    assert_equal direct_numbers.sort.reverse, direct_numbers

    assert_select "#shared_rooms [data-sorted-list-target='item'][data-sorted-list-name]"
    assert_select "#direct_rooms [data-sorted-list-target='item'][data-sorted-list-number]"
  end

  test "empty collections keep their stable Turbo and sorting targets" do
    users(:david).memberships.update_all(involvement: "invisible")

    get user_sidebar_url

    assert_select "turbo-frame#direct_rooms_control #direct_rooms[data-controller='sorted-list']"
    assert_select "#shared_rooms[data-controller='sorted-list']"
    assert_select "#direct_rooms a.direct:not(.direct__new)", count: 0
    assert_select "#shared_rooms a.room", count: 0
  end

  test "suggested direct participants remain actions outside the sortable room list" do
    get user_sidebar_url

    assert_select "#direct_rooms .direct", count: users(:david).rooms.directs.count
    assert_select "#direct_rooms ~ div form.button_to button.direct[aria-label^='Start a ping with']"
    assert_select "#direct_rooms ~ div [data-sorted-list-target='item']", count: 0
  end

  test "unread directs" do
    room = rooms(:david_and_jason)
    room.messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.select { |m| m.room.direct? && m.unread? }.count
    assert_select "#direct_rooms[data-action='rooms-list:unread@window->sorted-list#updateItem']" do
      assert_select "##{dom_id(room, :list)}.direct.unread[data-sorted-list-number]"
    end
  end
  test "unread other" do
    rooms(:watercooler).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.reject { |m| m.room.direct? || !m.unread? }.count
  end
end
