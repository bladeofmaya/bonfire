require "test_helper"

class Rooms::Directs::ClosuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @room = rooms(:david_and_jason)
    @membership = memberships(:david_david_and_jason)
  end

  test "closing hides only the current user's direct conversation" do
    assert_no_difference -> { Room.count } do
      post rooms_direct_closure_url(@room)
    end

    assert_response :no_content
    assert_rendered_turbo_stream_broadcast users(:david), :rooms,
      action: "remove", target: dom_id(@room, :list)
    assert @membership.reload.involved_in_invisible?
    assert @room.memberships.where.not(user: users(:david)).none?(&:involved_in_invisible?)
    assert @room.reload.persisted?
  end

  test "closing clears unread state" do
    @membership.update!(unread_at: Time.current, unread_count: 4)

    post rooms_direct_closure_url(@room)

    assert_nil @membership.reload.unread_at
    assert_equal 0, @membership.unread_count
  end

  test "cannot close another user's direct conversation" do
    sign_in :jz

    assert_raises ActiveRecord::RecordNotFound do
      post rooms_direct_closure_url(@room)
    end
    refute @membership.reload.involved_in_invisible?
  end

  test "cannot use the endpoint for a shared room" do
    assert_raises ActiveRecord::RecordNotFound do
      post rooms_direct_closure_url(rooms(:watercooler))
    end
  end
end
