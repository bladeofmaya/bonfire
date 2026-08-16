require "application_system_test_case"

class SendingMessagesTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
    join_room rooms(:designers)
  end

  test "sending messages between two users" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)
    end

    join_room rooms(:designers)
    send_message "Is this thing on?"

    using_session("Kevin") do
      join_room rooms(:designers)
      assert_message_text "Is this thing on?"

      send_message "👍👍"
    end

    join_room rooms(:designers)
    assert_message_text "👍👍"
  end

  test "editing messages" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)
    end

    within_message messages(:third) do
      reveal_message_actions
      find(".message__edit-btn").click
      fill_in_rich_text_area "message_body", with: "Redacted!"
      click_on "Save changes"
    end

    using_session("Kevin") do
      join_room rooms(:designers)

      assert_message_text "Redacted!"
    end
  end

  test "linking to another channel with a hashtag" do
    join_room rooms(:designers)

    find("trix-editor[aria-label='Write a message']").send_keys("#H")
    find("suggestion-option", text: "HQ").click
    assert_selector "trix-editor [data-trix-attachment]"
    click_on "Send Message"

    assert_selector ".message__body a.channel-reference", text: "HQ"
    page.document.synchronize do
      find(".message__body a.channel-reference", text: "HQ").click
    end
    assert_current_path room_path(rooms(:hq))
  end

  test "deleting messages" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)

      assert_message_text "Third time's a charm."
    end

    within_message messages(:third) do
      reveal_message_actions
      find(".message__edit-btn").click

      accept_confirm do
        click_on "Delete message"
      end
    end

    using_session("Kevin") do
      assert_message_text "Third time's a charm.", count: 0
    end
  end
end
