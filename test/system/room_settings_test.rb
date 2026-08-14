require "application_system_test_case"

class RoomSettingsTest < ApplicationSystemTestCase
  setup do
    configure_streaming
    @room = rooms(:watercooler)
    sign_in "david@37signals.com"
    visit edit_rooms_closed_url(@room)
  end

  test "administrator switches tabs and enables the stream player" do
    assert_selector ".room-settings [role='tab']", count: 3
    assert_selector "#room-panel-general:not([hidden])"

    click_on "Streaming"

    assert_selector "[role='tab'][aria-selected='true']", text: "Streaming"
    assert_selector "#room-panel-streaming:not([hidden])"
    assert_not page.evaluate_script("document.querySelector('#room_stream_enabled').checked")

    find("label", text: "Enable stream player").click
    assert page.evaluate_script("document.querySelector('#room_stream_enabled').checked")
    fill_in "room[stream_player_url]", with: "https://stream.example.test/player"
    fill_in "room[stream_path]", with: "live"
    click_on "Save stream settings"

    assert_current_path edit_rooms_closed_path(@room)
    assert_equal "streaming", URI.parse(current_url).fragment
    assert page.evaluate_script("document.querySelector('#room_stream_enabled').checked")
    assert @room.reload.stream_enabled?
  end

  test "public rooms use the same tabbed settings dialog" do
    visit edit_rooms_open_url(rooms(:pets))

    assert_selector ".room-settings [role='tab']", count: 3
    click_on "Permissions"
    assert_selector "#room-panel-permissions:not([hidden])", text: "Everyone currently has access"

    click_on "Streaming"
    assert_selector "#room-panel-streaming:not([hidden]) form[action='#{room_stream_path(rooms(:pets))}']"
  end

  test "renames public and private rooms from general settings" do
    visit edit_rooms_open_url(rooms(:pets))
    fill_in "Room name", with: "Public lounge"
    click_on "Save general settings"

    assert_current_path room_path(rooms(:pets)), wait: 5
    assert_equal "Public lounge", rooms(:pets).reload.name

    visit edit_rooms_closed_url(@room)
    fill_in "Room name", with: "Private lounge"
    click_on "Save general settings"

    assert_current_path room_path(@room), wait: 5
    assert_equal "Private lounge", @room.reload.name
  end

  test "access mode switch stays on permissions" do
    public_room = rooms(:pets)
    visit edit_rooms_open_url(public_room, anchor: "permissions")

    find("a[href='#{edit_rooms_closed_path(public_room, anchor: "permissions")}']").click

    assert_current_path edit_rooms_closed_path(public_room)
    assert_equal "permissions", URI.parse(current_url).fragment
    assert_selector "[role='tab'][aria-selected='true']", text: "Permissions"
    assert_selector "#room-panel-permissions:not([hidden])"

    find("a[href='#{edit_rooms_open_path(public_room, anchor: "permissions")}']").click

    assert_current_path edit_rooms_open_path(public_room)
    assert_equal "permissions", URI.parse(current_url).fragment
    assert_selector "[role='tab'][aria-selected='true']", text: "Permissions"
    assert_button "Save permissions"
  end
end
