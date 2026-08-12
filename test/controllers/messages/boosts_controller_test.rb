require "test_helper"

class Messages::BoostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @message = messages(:first)
  end

  test "create" do
    original_message_cache_key = @message.cache_key_with_version

    assert_turbo_stream_broadcasts [ @message.room, :messages ], count: 1 do
      assert_difference -> { @message.boosts.count }, 1 do
        post message_boosts_url(@message, format: :turbo_stream), params: { boost: { content: "Morning!" } }
        assert_redirected_to message_boosts_url(@message)
      end
    end

    refute_equal original_message_cache_key, @message.reload.cache_key_with_version

    boost = Boost.last
    assert_rendered_turbo_stream_broadcast @message.room, :messages,
      action: "append", target: "boosts_message_#{@message.client_message_id}" do
      assert_select "##{dom_id(boost)}.boost[data-controller='boost-delete']", text: /Morning!/
    end
  end

  test "destroy" do
    boost = boosts(:first)

    assert_turbo_stream_broadcasts [ @message.room, :messages ], count: 1 do
      assert_difference -> { @message.boosts.count }, -1 do
        delete message_boost_url(@message, boost, format: :turbo_stream)
        assert_response :success
      end
    end

    assert_rendered_turbo_stream_broadcast @message.room, :messages,
      action: "remove", target: boost
  end
end
