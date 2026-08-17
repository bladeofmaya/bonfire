require "test_helper"

class Accounts::CustomEmotesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in :david }

  test "administrator creates, updates, and disables an emote" do
    assert_difference -> { CustomEmote.count }, 1 do
      post account_custom_emotes_url, params: { custom_emote: {
        shortcode: "MayaPog", image: tiny_emote_upload
      } }
    end

    emote = CustomEmote.last
    assert_redirected_to edit_account_url(tab: "emotes", anchor: "emotes")
    assert_equal "mayapog", emote.shortcode

    patch account_custom_emote_url(emote), params: { custom_emote: { shortcode: "maya-pog" } }
    assert_equal "maya-pog", emote.reload.shortcode

    delete account_custom_emote_url(emote)
    assert emote.reload.disabled_at?
    assert emote.image.attached?
  end

  test "ordinary members cannot manage emotes" do
    sign_in :kevin

    post account_custom_emotes_url, params: { custom_emote: {
      shortcode: "nope", image: tiny_emote_upload
    } }

    assert_response :forbidden
  end
end
