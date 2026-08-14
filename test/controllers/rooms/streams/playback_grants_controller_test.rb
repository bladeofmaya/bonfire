require "test_helper"

class Rooms::Streams::PlaybackGrantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @key = configure_streaming
    @room = rooms(:watercooler)
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live", stream_title: "Town Hall")
    sign_in :david
  end

  test "active member receives a no-store read-only grant" do
    post room_stream_playback_grant_url(@room), as: :json

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    grant = response.parsed_body
    assert_equal "https://stream.example.test", grant["player_origin"]
    assert_equal "https://stream.example.test/player", grant["player_url"]
    assert_equal "live", grant["stream_path"]
    assert_in_delta 60.seconds.from_now, Time.iso8601(grant["expires_at"]), 2.seconds

    payload = JWT.decode(grant["token"], @key, true, algorithm: "ES256").first
    assert_equal [ { "action" => "read", "path" => "live" } ], payload["mediamtx_permissions"]
  end

  test "grant parameters cannot expand permission or change the stream" do
    post room_stream_playback_grant_url(@room), params: {
      stream_path: "*", action: "publish", room_id_override: rooms(:designers).id, user_id: users(:jason).id
    }, as: :json

    payload = JWT.decode(response.parsed_body.fetch("token"), nil, false).first
    assert_equal @room.id.to_s, payload["room_id"]
    assert_equal [ { "action" => "read", "path" => "live" } ], payload["mediamtx_permissions"]
  end

  test "anonymous request is unauthorized rather than redirected" do
    delete session_url
    post room_stream_playback_grant_url(@room), as: :json
    assert_response :unauthorized
  end

  test "non-member and removed member cannot discover or refresh the stream" do
    sign_in :jz
    post room_stream_playback_grant_url(@room), as: :json
    assert_response :not_found

    sign_in :david
    memberships(:david_watercooler).destroy!
    post room_stream_playback_grant_url(@room), as: :json
    assert_response :not_found
  end

  test "installation administrator has no implicit access without membership" do
    memberships(:jason_watercooler).destroy!
    sign_in :jason

    post room_stream_playback_grant_url(@room), as: :json

    assert_response :not_found
  end

  test "banned and deactivated users are forbidden" do
    %i[ banned deactivated ].each do |status|
      users(:david).update_column(:status, User.statuses.fetch(status))
      post room_stream_playback_grant_url(@room), as: :json
      assert_response :forbidden
      users(:david).update_column(:status, User.statuses.fetch(:active))
    end
  end

  test "bot keys cannot receive browser playback grants" do
    delete session_url
    post room_stream_playback_grant_url(@room), params: { bot_key: users(:bender).bot_key }, as: :json
    assert_response :forbidden
  end

  test "disabled and incomplete streams do not issue grants" do
    @room.update!(stream_enabled: false)
    post room_stream_playback_grant_url(@room), as: :json
    assert_response :not_found

    @room.update_columns(stream_enabled: true, stream_path: nil)
    post room_stream_playback_grant_url(@room), as: :json
    assert_response :unprocessable_entity
  end
end
