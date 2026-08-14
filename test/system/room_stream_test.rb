require "application_system_test_case"

class RoomStreamingTest < ApplicationSystemTestCase
  setup do
    configure_streaming
    @room = rooms(:designers)
    @room.update!(stream_enabled: true, stream_player_url: "https://stream.example.test/player", stream_path: "live", stream_title: "Town Hall")
    sign_in "jz@37signals.com"
    visit room_url(@room)
  end

  test "player messages require the exact origin and source and expose every state" do
    assert_selector ".room-stream__status", text: "Connecting to stream…"

    dispatch_player_message(type: "player.state", state: "live", origin: "https://evil.example")
    assert_no_selector ".room-stream__status", text: "Stream is live", wait: 0.2

    dispatch_player_message(type: "player.state", state: "live", source: "window")
    assert_no_selector ".room-stream__status", text: "Stream is live", wait: 0.2

    {
      offline: "Stream is offline",
      connecting: "Connecting to stream…",
      live: "Stream is live",
      reconnecting: "Reconnecting to stream…",
      error: "The stream could not be loaded",
      unauthorized: "Stream access is unavailable"
    }.each do |state, text|
      visit room_url(@room) if state == :unauthorized
      dispatch_player_message(type: "player.state", state: state)
      assert_selector ".room-stream__viewport[data-state='#{state}']"
      assert_selector ".room-stream__status", text: text
    end
  end

  test "grant refresh rechecks membership and stops after access removal" do
    dispatch_player_message(type: "player.ready")
    assert_selector ".room-stream__status", text: "Connecting to stream…"

    memberships(:jz_designers).destroy!
    dispatch_player_message(type: "token.refresh_requested")

    assert_selector ".room-stream__status", text: "Stream access is unavailable", wait: 5
  end

  test "player ready sends an in-memory authorization message to the exact origin" do
    page.execute_script <<~JS
      (() => {
        const frame = document.querySelector(".room-stream__frame")
        window.__streamAuthorizations = []
        frame.addEventListener("load", () => {
          frame.contentWindow.postMessage = (message, origin) => window.__streamAuthorizations.push({ message, origin })
        }, { once: true })
        frame.src = "about:blank"
      })()
    JS
    assert_selector ".room-stream__frame"
    dispatch_player_message(type: "player.ready")

    Timeout.timeout(5) do
      sleep 0.05 until page.evaluate_script("window.__streamAuthorizations.length") == 1
    end
    authorization = page.evaluate_script("window.__streamAuthorizations[0]")

    assert_equal "https://stream.example.test", authorization.fetch("origin")
    assert_equal "playback.authorize", authorization.dig("message", "type")
    assert_equal "live", authorization.dig("message", "stream_path")
    assert authorization.dig("message", "token").present?
    assert_nil page.evaluate_script("localStorage.getItem('playback_token')")
    assert_not_includes page.html, authorization.dig("message", "token")
  end

  test "stream remains in normal flow at desktop and mobile widths" do
    assert_selector "main > .room-stream + #message-area"
    assert_no_selector ".room-stream[style*='position: fixed']"

    page.current_window.resize_to(390, 844)
    assert_selector ".room-stream__viewport"
    assert_selector "footer .composer"
  end

  private
    def dispatch_player_message(type:, state: nil, origin: "https://stream.example.test", source: "frame.contentWindow")
      page.execute_script <<~JS
        (() => {
          const frame = document.querySelector(".room-stream__frame")
          window.dispatchEvent(new MessageEvent("message", {
            origin: #{origin.to_json},
            source: #{source},
            data: #{ { source: "rtmp-homebrew", version: 1, type: type, state: state }.compact.to_json }
          }))
        })()
      JS
    end
end
