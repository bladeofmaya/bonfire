require "application_system_test_case"

class ChannelOrderingTest < ApplicationSystemTestCase
  setup { sign_in "david@37signals.com" }

  test "administrator reorders channels with the keyboard and the order persists" do
    assert_selector "button[aria-label='Reorder HQ'] svg.lucide-grip-vertical"
    move_handle = find_button("Reorder HQ")
    move_handle.send_keys(:arrow_up)

    assert_selector "#channel-order-status", text: "Channel order updated.", visible: false
    assert_selector "#shared_rooms .channel-order-item__handle", count: 4
    assert_no_selector "#shared_rooms .channel-order-item > button:not(.channel-order-item__handle)"
    assert_equal [ "HQ", "All Pets" ], all("#shared_rooms .channel-order-item").first(2).map(&:text).map { |text| text.lines.first.strip }

    refresh
    assert_equal [ rooms(:hq).id, rooms(:pets).id ],
      all("#shared_rooms .channel-order-item").first(2).map { |item| item["data-sorted-list-id"].to_i }
  end

  test "reorder controls remain usable in the mobile sidebar" do
    page.current_window.resize_to(390, 844)

    assert_button "Reorder HQ", visible: true
  end
end
