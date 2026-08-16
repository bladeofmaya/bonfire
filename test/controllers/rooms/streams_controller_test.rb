require "test_helper"

class Rooms::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    configure_streaming
    sign_in :david
  end

  test "installation administrator configures a closed room stream" do
    room = rooms(:watercooler)

    patch room_stream_url(room), params: { room: {
      stream_enabled: "1",
      stream_player_url: "https://stream.example.test/player",
      stream_path: "live",
      stream_title: "Town Hall",
      stream_description: "Fridays at 20:00"
    } }

    assert_redirected_to "#{edit_rooms_closed_url(room)}#streaming"
    assert room.reload.stream_configured?
    assert_equal "Town Hall", room.stream_title
    assert_equal "Fridays at 20:00", room.stream_description.to_plain_text
  end

  test "closed room settings show stream controls only to installation administrators" do
    get edit_rooms_closed_url(rooms(:watercooler))
    assert_select ".room-settings button[role='tab']", count: 3
    assert_select "button[data-profile-tabs-name='general']", text: "General"
    assert_select "button[data-profile-tabs-name='permissions']", text: "Permissions"
    assert_select "button[data-profile-tabs-name='streaming']", text: "Streaming"
    assert_select "form[action='#{room_stream_path(rooms(:watercooler))}']" do
      assert_select "label .switch input.switch__input[name='room[stream_enabled]'][type='checkbox']"
      assert_select "input[name='room[stream_player_url]']"
      assert_select "input[name='room[stream_path]']"
      assert_select "input[name='room[stream_title]']"
      assert_select ".stream-settings__description-editor trix-editor[aria-label='Stream description and schedule']"
      assert_select "input[name='room[stream_poster]'][type='file']"
    end

    sign_in :jz
    get edit_rooms_closed_url(rooms(:designers))
    assert_select ".stream-settings", count: 0
    assert_select "button[data-profile-tabs-name='streaming']", count: 0
  end

  test "administrator uploads and removes a poster" do
    room = rooms(:watercooler)
    patch room_stream_url(room), params: { room: {
      stream_enabled: "0", stream_poster: fixture_file_upload("moon.jpg", "image/jpeg")
    } }
    assert room.reload.stream_poster.attached?

    patch room_stream_url(room), params: { room: { stream_enabled: "0", remove_stream_poster: "1" } }
    assert_not room.reload.stream_poster.attached?
  end

  test "room creator who is not an installation administrator cannot configure streaming" do
    room = rooms(:designers)
    room.update_column(:creator_id, users(:jz).id)
    sign_in :jz

    patch room_stream_url(room), params: { room: { stream_enabled: "1", stream_player_url: "https://stream.example.test/player", stream_path: "live" } }

    assert_response :forbidden
    assert_not room.reload.stream_enabled?
  end

  test "administrator configures an open room stream" do
    patch room_stream_url(rooms(:pets)), params: { room: { stream_enabled: "1", stream_player_url: "https://stream.example.test/player", stream_path: "live" } }

    assert_redirected_to "#{edit_rooms_open_url(rooms(:pets))}#streaming"
    assert rooms(:pets).reload.stream_configured?
  end

  test "invalid configuration rerenders clear errors without persisting" do
    room = rooms(:watercooler)
    patch room_stream_url(room), params: { room: { stream_enabled: "1", stream_player_url: "https://evil.example/player", stream_path: "../live" } }

    assert_response :unprocessable_entity
    assert_select ".stream-settings [role='alert']", text: /Stream player url origin is not allowed/
    assert_not room.reload.stream_enabled?
  end
end
