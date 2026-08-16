require "test_helper"

class Autocompletable::RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "returns matching visible shared channels except the current channel" do
    get autocompletable_rooms_url(format: :json), params: { room_id: rooms(:pets).id, query: "all" }

    assert_response :success
    assert_equal [ "All Talk" ], response.parsed_body.pluck("name")
    assert_equal rooms(:watercooler).attachable_sgid, response.parsed_body.first["sgid"]
    assert_equal room_path(rooms(:watercooler)), response.parsed_body.first["url"]
    assert_not response.parsed_body.first.key?("avatar_url")
  end

  test "does not return direct conversations or hidden channels" do
    memberships(:david_designers).update!(involvement: :invisible)

    get autocompletable_rooms_url(format: :json), params: { room_id: rooms(:pets).id }

    assert_response :success
    room_ids = response.parsed_body.pluck("value")
    assert_not_includes room_ids, rooms(:designers).id
    assert_empty room_ids & Room.directs.ids
  end

  test "requires membership in the composing channel" do
    sign_in :kevin

    assert_raises ActiveRecord::RecordNotFound do
      get autocompletable_rooms_url(format: :json), params: { room_id: rooms(:watercooler).id }
    end
  end
end
