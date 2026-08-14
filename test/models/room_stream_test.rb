require "test_helper"

class RoomStreamTest < ActiveSupport::TestCase
  setup { configure_streaming }

  test "rooms accept an allowed stream configuration regardless of access type" do
    room = rooms(:watercooler)
    room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live/main", stream_title: "Town Hall")

    assert room.stream_configured?
    assert_equal "https://stream.example.test", room.stream_player_origin

    [ rooms(:pets), rooms(:david_and_jason) ].each do |room|
      room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live")
      assert room.stream_configured?
    end
  end

  test "player URL rejects credentials query fragment insecure and unlisted origins" do
    room = rooms(:watercooler)
    invalid_urls = [
      "http://stream.example.test/player",
      "https://user:secret@stream.example.test/player",
      "https://stream.example.test/player?token=secret",
      "https://stream.example.test/player#fragment",
      "https://other.example.test/player"
    ]

    invalid_urls.each do |url|
      room.assign_attributes(stream_enabled: true, stream_player_url: url, stream_path: "live")
      assert_not room.valid?, url
    end
  end

  test "stream path is opaque and cannot contain traversal or a leading slash" do
    room = rooms(:watercooler)
    [ "", "/live", "../live", "live/../other", "live?token=x", "*" ].each do |path|
      room.assign_attributes(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: path)
      assert_not room.valid?, path
    end
  end
end
