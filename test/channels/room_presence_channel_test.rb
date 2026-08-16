require "test_helper"

class RoomPresenceChannelTest < ActionCable::Channel::TestCase
  tests RoomPresenceChannel

  setup do
    @room = rooms(:designers)
    @signed_stream_name = Turbo::StreamsChannel.signed_stream_name [ @room, :presence ]
  end

  test "a member may subscribe to the room presence stream" do
    stub_connection(current_user: users(:kevin))
    subscribe signed_stream_name: @signed_stream_name

    assert subscription.confirmed?
    assert_has_stream Turbo.signed_stream_verifier.verified(@signed_stream_name)
  end

  test "a non-member may not subscribe to the room presence stream" do
    stub_connection(current_user: users(:bender))
    subscribe signed_stream_name: @signed_stream_name

    assert subscription.rejected?
  end

end

class RoomPresenceViaStockTurboChannelTest < ActionCable::Channel::TestCase
  tests Turbo::StreamsChannel

  test "the stock Turbo channel may not bypass room presence authorization" do
    stub_connection(current_user: users(:kevin))
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ rooms(:designers), :presence ])

    assert subscription.rejected?
  end
end
