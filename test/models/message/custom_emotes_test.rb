require "test_helper"

class Message::CustomEmotesTest < ActiveSupport::TestCase
  setup do
    @emote = accounts(:signal).custom_emotes.new(shortcode: "mayapog")
    attach_test_emote_image(@emote)
    @emote.save!
  end

  test "expands a typed shortcode into a durable Action Text attachment" do
    assert_includes Current.account.active_custom_emotes, @emote
    message = Message.create!(room: rooms(:pets), creator: users(:david), body: "Well played :MayaPog:!")
    message.reload

    assert_includes message.body.body.to_html, @emote.attachable_sgid
    assert_equal "Well played :mayapog:!", message.body.to_plain_text
    assert_includes message.body.to_s, "img"
  end

  test "leaves unknown shortcodes and code samples alone" do
    message = Message.create!(room: rooms(:pets), creator: users(:david),
      body: "<div>:unknown: <code>:mayapog:</code></div>")

    assert_equal ":unknown: :mayapog:", message.body.to_plain_text
    assert_not_includes message.body.body.to_html, @emote.attachable_sgid
  end
end
