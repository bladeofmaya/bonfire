require "test_helper"

class Users::SidebarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get user_sidebar_url

    assert_select "turbo-frame#user_sidebar[data-turbo-permanent][target='_top']" \
                  "[data-controller='rooms-list read-rooms turbo-frame']" \
                  "[data-rooms-list-current-class='room-list--current']"
    assert_select ".sidebar__container.channel-list"
    assert_select ".channel-list__header" do
      assert_select "img.channel-list__logo[src*='account/logo']"
      assert_select ".channel-list__account-name", text: accounts(:signal).name
      assert_select "details.context-menu.channel-list__server-menu summary.context-menu__trigger", text: accounts(:signal).name
      assert_select "a.context-menu__item[href='#{edit_account_path}']", text: "Server Settings"
      assert_select "a.channel-list__invite[href='#{account_invitation_path}'][data-turbo-frame='account_invitation_dialog']" \
                    "[aria-label='Invite people'] [data-lucide='user-round-plus']"
    end
    assert_select "section.channel-list__section[aria-labelledby='channels-heading']", text: /Channels/ do
      assert_select ".channel-list__section-header" do
        assert_select "h2", text: "Channels"
        assert_select "a.channel-list__new-channel[href='#{new_rooms_open_path}'][aria-label='Create a channel']"
      end
    end
    assert_select "section.channel-list__directs.flex.flex-column.gap[aria-labelledby='direct-messages-heading']" do
      assert_select "h2", text: "Direct Messages"
      assert_select "a.channel-list__new-direct[href='#{new_rooms_direct_path}']" \
                    "[data-turbo-frame='direct_conversation_dialog'][aria-label='Start a ping']"
      assert_select "turbo-frame#direct_rooms_control"
    end
    assert_select "turbo-frame#direct_conversation_dialog"
    assert_select "#shared_rooms.contents[data-controller~='sorted-list'][data-controller~='channel-order']"
    assert_select "#direct_rooms.contents[data-controller='sorted-list']" \
                  "[data-action='rooms-list:unread@window->sorted-list#updateItem']"

    users(:david).rooms.opens.each do |room|
      assert_select "##{dom_id(room, :list)}[data-room-id='#{room.id}'][data-sorted-list-position='#{room.position}'] a.room", text: room.name
    end
  end

  test "subscribes to global and user-specific room updates and preserves shell controls" do
    get user_sidebar_url

    assert_select "turbo-frame#user_sidebar" do
      assert_select "turbo-cable-stream-source", count: 2
      assert_select "button.btn--icon.sidebar__toggle[data-action='toggle-class#toggle']", text: "Open menu"
    end

    assert_select ".user-dock" do
      assert_select "a.user-dock__profile[href='#{user_path(users(:david))}'][aria-label='View my profile']" do
        assert_select "strong", text: users(:david).name
      end
      assert_select ".user-dock__identity > span", text: "Online"
      assert_select "a.user-dock__settings[href='#{user_profile_path}'][aria-label='User settings']"
    end
    assert_select ".sidebar__tools a[href='#{edit_account_path}']", count: 0
  end

  test "shows channel creation beside the heading for administrators" do
    get user_sidebar_url

    assert_select ".channel-list__section-header a.channel-list__new-channel[href='#{new_rooms_open_path}']"
    assert_select "a.rooms__new-btn", count: 0
  end

  test "hides channel creation from members" do
    sign_in :jz

    get user_sidebar_url

    assert_select "a.channel-list__new-channel", count: 0
  end

  test "hides administrator server actions and dropdown from members" do
    sign_in :jz

    get user_sidebar_url

    assert_select "a.channel-list__invite", count: 0
    assert_select "details.context-menu.channel-list__server-menu", count: 0
    assert_select ".channel-list__server-identity", text: accounts(:signal).name
    assert_select "a[href='#{edit_account_path}']", count: 0
    assert_select "turbo-frame#account_invitation_dialog", count: 1
    assert_select "#shared_rooms[data-controller='sorted-list'] .channel-order-item__handle", count: 0
  end

  test "initial shared and direct items expose their distinct sorting contracts" do
    get user_sidebar_url

    shared_positions = css_select("#shared_rooms [data-sorted-list-position]").map { |item| item["data-sorted-list-position"].to_i }
    assert_equal shared_positions.sort, shared_positions

    direct_numbers = css_select("#direct_rooms [data-sorted-list-number]").map { |item| item["data-sorted-list-number"].to_i }
    assert_equal direct_numbers.sort.reverse, direct_numbers

    assert_select "#shared_rooms [data-sorted-list-target='item'][data-sorted-list-position][data-sorted-list-id]"
    assert_select "#direct_rooms [data-sorted-list-target='item'][data-sorted-list-number]"
  end

  test "empty collections keep their stable Turbo and sorting targets" do
    users(:david).memberships.update_all(involvement: "invisible")

    get user_sidebar_url

    assert_select "turbo-frame#direct_rooms_control #direct_rooms[data-controller='sorted-list']"
    assert_select "#shared_rooms[data-controller~='sorted-list']"
    assert_select "#direct_rooms a.direct", count: 0
    assert_select "#shared_rooms a.room", count: 0
  end

  test "direct messages list contains conversations without the old ping suggestions" do
    get user_sidebar_url

    assert_select "#direct_rooms .direct", count: users(:david).rooms.directs.count
    assert_select "form.button_to button.direct[aria-label^='Start a ping with']", count: 0
    assert_select ".direct__close", count: users(:david).rooms.directs.count
  end

  test "unread directs" do
    room = rooms(:david_and_jason)
    room.messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.select { |m| m.room.direct? && m.unread? }.count
    assert_select "#direct_rooms[data-action='rooms-list:unread@window->sorted-list#updateItem']" do
      assert_select "##{dom_id(room, :list)}[data-sorted-list-number] a.direct.unread"
    end
  end
  test "unread other" do
    rooms(:watercooler).messages.create! client_message_id: 999,
      body: "Hello #{mention_attachment_for(:david)}", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.reject { |m| m.room.direct? || !m.unread? }.count
    assert_select "##{dom_id(rooms(:watercooler), :list)} .channel__mention-count", text: "1"
  end
end
