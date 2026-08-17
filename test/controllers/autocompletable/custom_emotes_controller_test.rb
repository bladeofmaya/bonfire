require "test_helper"

class Autocompletable::CustomEmotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @emote = accounts(:signal).custom_emotes.new(shortcode: "mayapog")
    attach_test_emote_image(@emote, filename: "mayapog.png")
    @emote.save!
  end

  test "returns active matching emotes as Action Text attachments" do
    get autocompletable_custom_emotes_url(format: :json), params: { query: "pOg" }

    assert_response :success
    result = response.parsed_body.first
    assert_equal ":mayapog:", result["name"]
    assert_equal @emote.attachable_sgid, result["sgid"]
    assert_match %r{/rails/active_storage/}, result["avatar_url"]
  end

  test "omits disabled emotes" do
    @emote.disable!

    get autocompletable_custom_emotes_url(format: :json)

    assert_empty response.parsed_body
  end
end
