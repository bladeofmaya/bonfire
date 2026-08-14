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
end
