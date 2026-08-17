require "test_helper"

class Messages::ActionMenuComponentTest < ComponentTestCase
  setup do
    @message = messages(:sixth)
    @permalink_url = "https://bonfire.test/rooms/#{@message.room.id}/at/#{@message.id}"
  end

  test "preserves popup, quick-boost, reply, copy, and edit contracts for text" do
    render_inline component

    assert_component_root ".message__actions[data-controller='soft-keyboard']"
    assert_selector "details[data-controller='popup'][data-popup-orientation-top-class='popup-orientation-top']" do
      assert_selector "summary.btn--icon.message__options-btn", text: "Message options"
      assert_selector "[data-popup-target='menu'].message__actions-menu", visible: false
    end
    assert_selector ".quick-boosts form", count: EmojiHelper::REACTIONS.size, visible: false
    assert_selector "form[data-turbo-frame='#{dom_id(@message, :boosting)}'][data-action='popup#close']", visible: false
    assert_selector "a.message__boost-btn[data-turbo-frame='#{dom_id(@message, :new_boost)}']", visible: false
    assert_selector "button[aria-label='Reply'][data-action='reply#reply']", visible: false
    assert_selector "button[aria-label='Copy link'][data-copy-to-clipboard-content-value='#{@permalink_url}']", visible: false
    assert_selector "a.message__edit-btn[aria-label='Edit'][data-turbo-frame='#{dom_id(@message, :edit)}']", visible: false
  end

  test "renders download and share actions instead of reply for an attachment" do
    @message.attachment.attach(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )

    render_inline component

    assert_selector "a[aria-label='Download'][href*='disposition=attachment']", visible: false
    assert_selector "button[aria-label='Share'][data-controller='web-share'][data-web-share-files-value]", visible: false
    assert_no_selector "button[aria-label='Reply']", visible: false
  end

  test "adds custom emotes without replacing system emoji reactions" do
    emote = accounts(:signal).custom_emotes.new(shortcode: "mayapog")
    attach_test_emote_image(emote, filename: "mayapog.png")
    emote.save!

    render_inline Messages::ActionMenuComponent.new(message: @message, permalink_url: @permalink_url, custom_emotes: [ emote ])

    assert_selector ".quick-boosts form", count: EmojiHelper::REACTIONS.size + 1, visible: false
    assert_selector "input[name='boost[custom_emote_id]'][value='#{emote.id}']", visible: false
    assert_selector "img.custom-emote[alt=':mayapog:']", visible: false
    assert_equal "boost[custom_emote_id]", page.first(".quick-boosts form input", visible: false)[:name]
  end

  test "keeps every action icon decorative" do
    render_inline component

    assert_selector ".message__actions img:not([aria-hidden='true'])", count: 0, visible: false
  end

  test "omits editing for stream chat messages" do
    @message.room.stubs(:stream_configured?).returns(true)

    render_inline component

    assert_no_selector "a.message__edit-btn", visible: false
    delete_path = Rails.application.routes.url_helpers.room_message_path(@message.room, @message)
    assert_selector "form[action='#{delete_path}'][data-turbo-confirm]", visible: false do
      assert_selector "button.message__stream-delete-btn[aria-label='Delete message']", visible: false
    end
  end

  private
    def component
      Messages::ActionMenuComponent.new(message: @message, permalink_url: @permalink_url)
    end
end
