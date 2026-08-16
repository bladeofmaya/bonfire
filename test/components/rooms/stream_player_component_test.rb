require "test_helper"

class Rooms::StreamPlayerComponentTest < ComponentTestCase
  setup do
    configure_streaming
    @room = rooms(:watercooler)
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live", stream_title: "Town Hall")
  end

  test "renders the exact iframe and browser protocol contract without a token" do
    render_inline Rooms::StreamPlayerComponent.new(room: @room)

    assert_component_root "section.room-stream[data-controller='room-stream']"
    assert_selector "[data-room-stream-player-origin-value='https://stream.example.test']"
    grant_path = Rails.application.routes.url_helpers.room_stream_playback_grant_path(@room)
    assert_selector "[data-room-stream-grant-url-value='#{grant_path}']"
    assert_selector "iframe[src='https://stream.example.test/player']" \
                    "[title='Town Hall live stream player']" \
                    "[sandbox='allow-scripts allow-same-origin allow-presentation']" \
                    "[allow='autoplay; fullscreen; picture-in-picture']" \
                    "[referrerpolicy='no-referrer']"
    assert_selector "[role='status'][aria-live='polite']", text: "Connecting to stream…"
    assert_no_match(/token|private.?key/i, rendered_content)
  end

  test "renders the direct Vidstack contract without placing a grant in HTML or the media URL" do
    Streaming::Configuration.stubs(:direct_player_enabled?).returns(true)

    render_inline Rooms::StreamPlayerComponent.new(room: @room)

    assert_selector "section.room-stream[data-room-stream-direct-value='true']" \
                    "[data-room-stream-media-url-value='https://stream.example.test/hls/live/index.m3u8']"
    assert_selector "media-player[data-room-stream-target='player'][autoplay][muted][playsinline]" do
      assert_selector "media-outlet"
      assert_selector "media-play-button[aria-label='Play or pause stream']"
      assert_selector "media-mute-button[aria-label='Mute or unmute stream']"
      assert_selector "media-pip-button[aria-label='Toggle picture in picture']"
      assert_selector "media-fullscreen-button[aria-label='Toggle fullscreen']"
    end
    assert_selector "button[data-action='room-stream#watchWithSound']", text: "Watch with sound"
    assert_no_selector "iframe"
    assert_no_match(/eyJ[a-zA-Z0-9_-]+\./, rendered_content)
  end
end
