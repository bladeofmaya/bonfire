require "test_helper"

class CustomEmoteTest < ActiveSupport::TestCase
  test "normalizes and validates shortcode and image" do
    emote = build_emote(shortcode: " Maya-Pog ")

    assert emote.save
    assert_equal "maya-pog", emote.shortcode
    assert_not build_emote(shortcode: "no spaces please").valid?
  end

  test "disabled emotes leave historical attachment rendering available" do
    emote = build_emote
    emote.save!
    attachment = ActionText::Attachment.from_attachable(emote)

    emote.disable!

    assert_not_includes accounts(:signal).custom_emotes.active, emote
    assert_equal emote, attachment.attachable
    assert_equal ":mayapog:", emote.attachable_plain_text_representation(nil)
    assert_includes ActionText::Content.new(attachment.to_html).to_s, "img"
    assert_includes ActionText::Content.new(attachment.to_html).to_s, ":mayapog:"
  end

  private
    def build_emote(shortcode: "mayapog")
      CustomEmote.new(account: accounts(:signal), shortcode:).tap do |emote|
        attach_test_emote_image(emote, filename: "mayapog.png")
      end
    end
end
