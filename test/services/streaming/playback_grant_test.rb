require "test_helper"

class Streaming::PlaybackGrantTest < ActiveSupport::TestCase
  setup do
    @key = configure_streaming
    @room = rooms(:watercooler)
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
  end

  test "issues a short-lived ES256 read-only token with minimal claims" do
    now = Time.zone.parse("2026-08-14 12:00:00 UTC")
    grant = Streaming::PlaybackGrant.new(room: @room, user: users(:david), now: now)
    payload, header = JWT.decode(grant.token, @key, true,
      algorithm: "ES256", audience: "rtmp-homebrew", verify_aud: true,
      issuer: "https://bonfire.example.test", verify_iss: true, verify_expiration: false)

    assert_equal "test-current-key", header["kid"]
    assert_equal "bonfire-user:#{users(:david).id}", payload["sub"]
    assert_equal @room.id.to_s, payload["room_id"]
    assert_equal now.to_i, payload["iat"]
    assert_equal 60, payload["exp"] - payload["iat"]
    assert_equal [ { "action" => "read", "path" => "live" } ], payload["mediamtx_permissions"]
    assert_match(/\A[0-9a-f-]{36}\z/, payload["jti"])
    assert_nil payload["email"]
    assert_nil payload["name"]
  end

  test "each token has a unique ID" do
    first = JWT.decode(Streaming::PlaybackGrant.new(room: @room, user: users(:david)).token, nil, false).first
    second = JWT.decode(Streaming::PlaybackGrant.new(room: @room, user: users(:david)).token, nil, false).first
    assert_not_equal first["jti"], second["jti"]
  end
end
