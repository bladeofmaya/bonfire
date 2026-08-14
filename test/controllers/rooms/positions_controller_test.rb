require "test_helper"

class Rooms::PositionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in :david }

  test "administrator moves a shared channel and receives an announcement" do
    room = rooms(:hq)
    displaced = rooms(:pets)

    patch room_positions_url, params: { room_ids: [ room.id, displaced.id, rooms(:watercooler).id, rooms(:designers).id ] }, as: :turbo_stream

    assert_response :success
    assert_equal 1, room.reload.position
    assert_equal 2, displaced.reload.position
    assert_select "turbo-stream[action='update'][target='channel-order-status']", text: /Channel order updated/
  end

  test "ordinary members cannot reorder channels" do
    sign_in :jz

    assert_no_changes -> { rooms(:hq).reload.position } do
      patch room_positions_url, params: { room_ids: [ rooms(:hq).id, rooms(:pets).id ] }
    end

    assert_response :forbidden
  end

  test "rejects duplicate and inaccessible room IDs" do
    patch room_positions_url, params: { room_ids: [ rooms(:pets).id, rooms(:pets).id ] }
    assert_response :unprocessable_entity

    patch room_positions_url, params: { room_ids: [ rooms(:pets).id, -1 ] }
    assert_response :unprocessable_entity
  end

  test "direct rooms cannot be reordered" do
    patch room_positions_url, params: { room_ids: [ rooms(:david_and_jason).id ] }

    assert_response :unprocessable_entity
    assert_nil rooms(:david_and_jason).reload.position
  end
end
