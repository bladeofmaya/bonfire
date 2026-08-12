require "test_helper"

class Messages::PresentationComponentTest < ComponentTestCase
  test "preserves the replace target and reply/messages body contracts" do
    message = message_with_body("Hello from Bonfire")

    render_inline Messages::PresentationComponent.new(message: message)

    assert_component_root "##{dom_id(message, :presentation)}[dir='auto']"
    assert_selector "[data-reply-target='body'][data-messages-target='body']", text: "Hello from Bonfire"
  end

  test "delegates rich-text filtering and link presentation to the established helper" do
    message = message_with_body('<script>alert("no")</script><a href="https://example.com">Example</a>')

    render_inline Messages::PresentationComponent.new(message: message)

    assert_no_selector "script"
    assert_selector "a[href='https://example.com']", text: "Example"
  end

  test "preserves sound controller and playback contracts" do
    message = message_with_body("/play bell")

    render_inline Messages::PresentationComponent.new(message: message)

    assert_selector ".sound[data-controller='sound'][data-action='messages:play->sound#play'][data-sound-url-value]"
    assert_selector "button[data-action='sound#play']", text: "🔊"
  end

  private
    def message_with_body(body)
      Message.create!(
        room: rooms(:watercooler),
        creator: users(:david),
        client_message_id: SecureRandom.uuid,
        body: body
      )
    end
end
